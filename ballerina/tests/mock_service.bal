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
import ballerina/lang.regexp;

// A mock of arXiv's `/api/query` endpoint, driven entirely by the `search_query` string, so
// each test can select its own scenario without shared state leaking between tests. The real
// `Client` is pointed here in tests via its `serviceUrl` init parameter (`MOCK_SERVICE_URL`).
//
// `search_query` is treated as `case=<scenario>;total=<n>`, e.g. `case=http500-once;total=5`.
// A query with no `case=` segment is treated as the "normal" scenario with 5 total results.
const string MOCK_SERVICE_URL = "http://localhost:9099";

listener http:Listener mockListener = new (9099);

isolated map<int> attemptCounts = {};

isolated function nextAttempt(string caseName, int startIndex) returns int {
    string key = string `${caseName}:${startIndex}`;
    lock {
        int attempt = attemptCounts[key] ?: 0;
        attemptCounts[key] = attempt + 1;
        return attempt;
    }
}

type CaseConfig record {|
    string caseName;
    int total;
|};

isolated function parseCaseConfig(string searchQuery) returns CaseConfig {
    string caseName = "normal";
    int total = 5;
    string[] segments = regexp:split(re `;`, searchQuery);
    foreach string segment in segments {
        string[] parts = regexp:split(re `=`, segment);
        if parts.length() != 2 {
            continue;
        }
        if parts[0] == "case" {
            caseName = parts[1];
        } else if parts[0] == "total" {
            int|error parsedTotal = int:fromString(parts[1]);
            if parsedTotal is int {
                total = parsedTotal;
            }
        }
    }
    return {caseName, total};
}

isolated function buildEntryXml(string entryId) returns string {
    return string `
        <entry>
            <id>https://arxiv.org/abs/${entryId}</id>
            <updated>2020-01-01T00:00:00Z</updated>
            <published>2020-01-01T00:00:00Z</published>
            <title>Paper ${entryId}</title>
            <summary>Summary of paper ${entryId}</summary>
            <author><name>Author ${entryId}</name></author>
            <arxiv:primary_category xmlns:arxiv="http://arxiv.org/schemas/atom" term="cs.AI"/>
            <category term="cs.AI"/>
            <link href="https://arxiv.org/abs/${entryId}" rel="alternate" type="text/html"/>
            <link title="pdf" href="https://arxiv.org/pdf/${entryId}" rel="related" type="application/pdf"/>
        </entry>`;
}

isolated function buildFeedXml(int totalResults, int startIndex, string[] entryIds) returns string {
    string entries = "";
    foreach string entryId in entryIds {
        entries += buildEntryXml(entryId);
    }
    return buildFeedXmlFromEntries(totalResults, startIndex, entries);
}

isolated function buildFeedXmlFromEntries(int totalResults, int startIndex, string entries) returns string {
    return string `<?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
        <opensearch:totalResults>${totalResults}</opensearch:totalResults>
        <opensearch:startIndex>${startIndex}</opensearch:startIndex>
        ${entries}
    </feed>`;
}

// A single entry whose <title> echoes the received User-Agent header, so tests can assert on
// what the client actually sent over the wire.
isolated function buildEchoEntryXml(string title) returns string {
    return string `
        <entry>
            <id>https://arxiv.org/abs/echo</id>
            <updated>2020-01-01T00:00:00Z</updated>
            <published>2020-01-01T00:00:00Z</published>
            <title>${title}</title>
            <summary>User-Agent echo</summary>
        </entry>`;
}

isolated function feedResponse(string body) returns http:Response {
    http:Response response = new;
    response.statusCode = http:STATUS_OK;
    response.setXmlPayload(checkpanic xml:fromString(body));
    return response;
}

isolated function errorResponse(int statusCode) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setTextPayload("mock failure");
    return response;
}

service /api on mockListener {

    resource function get 'query(@http:Header {name: "User-Agent"} string? userAgent,
            string search_query = "", string id_list = "", int 'start = 0,
            int max_results = 100) returns http:Response {
        if id_list != "" {
            string[] ids = regexp:split(re `,`, id_list);
            return feedResponse(buildFeedXml(ids.length(), 0, ids));
        }

        CaseConfig config = parseCaseConfig(search_query);
        int attempt = nextAttempt(config.caseName, 'start);
        int remaining = config.total - 'start;
        int pageCount = remaining < max_results ? remaining : max_results;
        if pageCount < 0 {
            pageCount = 0;
        }

        boolean isFirstPage = 'start == 0;

        if config.caseName == "echo-user-agent" {
            return feedResponse(buildFeedXmlFromEntries(1, 0, buildEchoEntryXml(userAgent ?: "absent")));
        }
        if config.caseName == "http500-always" {
            return errorResponse(http:STATUS_INTERNAL_SERVER_ERROR);
        }
        if config.caseName == "http500-once" && attempt == 0 {
            return errorResponse(http:STATUS_INTERNAL_SERVER_ERROR);
        }
        if config.caseName == "empty-always" && !isFirstPage {
            return feedResponse(buildFeedXml(config.total, 'start, []));
        }
        if config.caseName == "empty-once" && !isFirstPage && attempt == 0 {
            return feedResponse(buildFeedXml(config.total, 'start, []));
        }

        string[] entryIds = [];
        foreach int i in 0 ..< pageCount {
            entryIds.push(string `${'start + i}`);
        }
        return feedResponse(buildFeedXml(config.total, 'start, entryIds));
    }
}
