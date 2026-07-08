// Copyright (c) 2026, Ayesh Almeida.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific
// language governing permissions and limitations under the License.

import ballerina/http;
import ballerina/lang.runtime;
import ballerina/time;

# A client for fetching search results from the arXiv API.
#
# This type encapsulates a pagination and retry strategy. Use `Client.search` to run a `Search`
# and lazily consume the matching `Result`s as a stream, without loading the whole result set
# into memory up front.
public isolated client class Client {
    private final http:Client httpClient;
    private final int pageSize;
    private final decimal delaySeconds;
    private final int numRetries;
    private time:Utc? lastRequestTime = ();

    # Constructs an arXiv API client with the specified options.
    #
    # The default parameters provide a reasonable strategy for most use cases. Extreme page
    # sizes, delays, or retry counts risk violating arXiv's
    # [API Terms of Use](https://info.arxiv.org/help/api/tou.html).
    #
    # + serviceUrl - The base URL of the arXiv API. Only useful for testing against a local mock service.
    # + pageSize - The maximum number of results fetched in a single API request. The API's limit
    # is 2000 results per page.
    # + delaySeconds - The number of seconds to wait between API requests. arXiv's Terms of Use
    # ask for no more than one request every three seconds.
    # + numRetries - The number of times to retry a failing API request before returning an error.
    public isolated function init(string serviceUrl = SERVICE_URL, int pageSize = 100,
            decimal delaySeconds = 3.0d, int numRetries = 3) returns error? {
        self.httpClient = check new (serviceUrl, {timeout: 30});
        self.pageSize = pageSize;
        self.delaySeconds = delaySeconds;
        self.numRetries = numRetries;
    }

    # Runs a `Search` and returns a lazily-fetched stream of matching `Result`s.
    #
    # Pages are fetched on demand as the stream is consumed, honoring `pageSize`, `delaySeconds`,
    # and `numRetries`. A failing page request surfaces as an `ArxivError` from `stream:next()`
    # once retries are exhausted.
    #
    # + searchQuery - The search to run.
    # + offset - The number of leading results to discard before yielding the rest.
    # + return - A stream of `Result`s.
    isolated remote function search(Search searchQuery, int offset = 0) returns stream<Result, error?> {
        int? maxResults = searchQuery.maxResults;
        int? remaining = ();
        if maxResults is int {
            int remainingCount = maxResults - offset;
            remaining = remainingCount < 0 ? 0 : remainingCount;
        }
        ResultIterator resultIterator = new (self, searchQuery, offset, remaining);
        return new stream<Result, error?>(resultIterator);
    }

    isolated function fetchPage(Search searchQuery, int startIndex, boolean firstPage) returns FeedPage|error {
        return self.fetchPageWithRetry(searchQuery, startIndex, firstPage, 0);
    }

    isolated function fetchPageWithRetry(Search searchQuery, int startIndex, boolean firstPage, int tryIndex) returns FeedPage|error {
        FeedPage|error result = self.requestPage(searchQuery, startIndex, firstPage, tryIndex);
        if result is error && tryIndex < self.numRetries {
            return self.fetchPageWithRetry(searchQuery, startIndex, firstPage, tryIndex + 1);
        }
        return result;
    }

    isolated function requestPage(Search searchQuery, int startIndex, boolean firstPage, int tryIndex) returns FeedPage|error {
        self.applyRateLimit();
        string path = check buildQueryPath(searchQuery, startIndex, self.pageSize);
        http:Response|http:ClientError response = self.httpClient->get(path);
        lock {
            self.lastRequestTime = time:utcNow();
        }
        if response is http:ClientError {
            return error HttpError(response.message(), url = path, retryCount = tryIndex, statusCode = 0);
        }
        if response.statusCode != http:STATUS_OK {
            return error HttpError(
                string `Page request resulted in HTTP ${response.statusCode}`,
                url = path,
                retryCount = tryIndex,
                statusCode = response.statusCode
            );
        }
        xml payload = check response.getXmlPayload();
        FeedPage page = check parseFeed(payload);
        if page.results.length() == 0 && !firstPage {
            return error EmptyPageError("Page of results was unexpectedly empty", url = path, retryCount = tryIndex);
        }
        return page;
    }

    isolated function applyRateLimit() {
        time:Utc? lastRequestTime;
        lock {
            lastRequestTime = self.lastRequestTime;
        }
        if lastRequestTime is time:Utc {
            decimal elapsedSeconds = time:utcDiffSeconds(time:utcNow(), lastRequestTime);
            if elapsedSeconds < self.delaySeconds {
                runtime:sleep(self.delaySeconds - elapsedSeconds);
            }
        }
    }
}

class ResultIterator {
    private final Client 'client;
    private final Search searchQuery;
    private int nextIndex;
    private int? remaining;
    private Result[] buffer = [];
    private int bufferIndex = 0;
    private boolean firstPageFetched = false;
    private boolean exhausted = false;
    private int totalResults = 0;

    isolated function init(Client 'client, Search searchQuery, int startIndex, int? remaining) {
        self.'client = 'client;
        self.searchQuery = searchQuery;
        self.nextIndex = startIndex;
        self.remaining = remaining;
        self.exhausted = remaining is int && remaining <= 0;
    }

    public isolated function next() returns record {|Result value;|}|error? {
        if self.remaining is int && self.remaining == 0 {
            return ();
        }
        if self.bufferIndex >= self.buffer.length() {
            check self.fetchNextPage();
            if self.buffer.length() == 0 {
                return ();
            }
        }
        Result value = self.buffer[self.bufferIndex];
        self.bufferIndex += 1;
        int? remaining = self.remaining;
        if remaining is int {
            self.remaining = remaining - 1;
        }
        return {value};
    }

    isolated function fetchNextPage() returns error? {
        if self.exhausted {
            self.buffer = [];
            self.bufferIndex = 0;
            return;
        }
        FeedPage page = check self.'client.fetchPage(self.searchQuery, self.nextIndex, !self.firstPageFetched);
        self.firstPageFetched = true;
        self.totalResults = page.totalResults;
        self.buffer = page.results;
        self.bufferIndex = 0;
        self.nextIndex += page.results.length();
        if page.results.length() == 0 || self.nextIndex >= self.totalResults {
            self.exhausted = true;
        }
    }
}
