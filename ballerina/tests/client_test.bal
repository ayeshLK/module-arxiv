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

import ballerina/test;
import ballerina/time;

// Every test below uses a scenario name unique to that test (see mock_service.bal), since the
// mock's retry-attempt counters are keyed by scenario name and persist for the whole test run.

@test:Config {}
function testSearchSinglePage() returns error? {
    Client testClient = check new (pageSize = 10, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=single-page;total=3"});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 3);
}

@test:Config {}
function testSearchMultiPagePagination() returns error? {
    Client testClient = check new (pageSize = 2, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=multi-page;total=5"});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 5);
    test:assertEquals(collected[0].entryId, "https://arxiv.org/abs/0");
    test:assertEquals(collected[4].entryId, "https://arxiv.org/abs/4");
}

@test:Config {}
function testSearchRespectsOffset() returns error? {
    Client testClient = check new (pageSize = 10, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=offset-case;total=5"}, 3);
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 2);
    test:assertEquals(collected[0].entryId, "https://arxiv.org/abs/3");
    test:assertEquals(collected[1].entryId, "https://arxiv.org/abs/4");
}

@test:Config {}
function testSearchRespectsMaxResults() returns error? {
    Client testClient = check new (pageSize = 3, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=max-results-case;total=10", maxResults: 4});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 4);
}

@test:Config {}
function testSearchByIdList() returns error? {
    Client testClient = check new (pageSize = 10, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({idList: ["2107.05580", "1605.08386"]});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 2);
    test:assertEquals(collected[0].entryId, "https://arxiv.org/abs/2107.05580");
    test:assertEquals(collected[1].entryId, "https://arxiv.org/abs/1605.08386");
}

@test:Config {}
function testRetryThenSucceedOnEmptyPage() returns error? {
    Client testClient = check new (pageSize = 2, delaySeconds = 0.01d, numRetries = 2, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=empty-once;total=5"});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 5);
}

@test:Config {}
function testEmptyPageErrorAfterRetriesExhausted() returns error? {
    Client testClient = check new (pageSize = 2, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=empty-always;total=5"});
    Result[] collected = [];
    error? err = results.forEach(function(Result r) {
        collected.push(r);
    });
    test:assertEquals(collected.length(), 2);
    test:assertTrue(err is EmptyPageError);
}

@test:Config {}
function testRetryThenSucceedOnHttpError() returns error? {
    Client testClient = check new (pageSize = 10, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=http500-once;total=3"});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 3);
}

@test:Config {}
function testHttpErrorAfterRetriesExhausted() returns error? {
    Client testClient = check new (pageSize = 10, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=http500-always;total=3"});
    Result[] collected = [];
    error? err = results.forEach(function(Result r) {
        collected.push(r);
    });
    test:assertEquals(collected.length(), 0);
    test:assertTrue(err is HttpError);
}

@test:Config {}
function testUserAgentHeaderSent() returns error? {
    Client testClient = check new (pageSize = 10, delaySeconds = 0.01d, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=echo-user-agent"});
    Result[] collected = check from Result r in results
        select r;
    test:assertEquals(collected.length(), 1);
    // The mock echoes the received User-Agent header back as the entry title.
    test:assertEquals(collected[0].title, USER_AGENT);
    // Guards against an unrendered `@toml.version@` placeholder ever shipping in version.bal.
    test:assertTrue(re `ballerina-arxiv/\d+\.\d+\.\d+`.isFullMatch(USER_AGENT));
}

@test:Config {}
function testRateLimitBetweenPageRequests() returns error? {
    decimal delaySeconds = 0.5d;
    Client testClient = check new (pageSize = 2, delaySeconds = delaySeconds, numRetries = 1, serviceUrl = MOCK_SERVICE_URL);
    stream<Result, error?> results = testClient->search({query: "case=rate-limit-case;total=4"});

    time:Utc before = time:utcNow();
    Result[] collected = check from Result r in results
        select r;
    time:Utc after = time:utcNow();

    test:assertEquals(collected.length(), 4);
    // Two page requests are made (pageSize=2, total=4), so exactly one inter-request delay applies.
    test:assertTrue(time:utcDiffSeconds(after, before) >= delaySeconds);
}
