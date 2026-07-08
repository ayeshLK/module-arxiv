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
import ballerina/url;

@test:Config {}
function testBuildQueryPathDefaults() returns error? {
    string path = check buildQueryPath({}, 0, 10);
    test:assertEquals(
        path,
        "/api/query?search_query=&id_list=&start=0&max_results=10&sortBy=relevance&sortOrder=descending"
    );
}

@test:Config {}
function testBuildQueryPathEncodesSpecialCharacters() returns error? {
    string path = check buildQueryPath({query: "au:del_maestro AND ti:checkerboard"}, 0, 10);
    test:assertTrue(path.includes("search_query=au%3Adel_maestro%20AND%20ti%3Acheckerboard"));
}

@test:Config {}
function testBuildQueryPathJoinsIdList() returns error? {
    string path = check buildQueryPath({idList: ["2107.05580", "1605.08386"]}, 0, 10);
    string encodedComma = check url:encode(",", "UTF-8");
    test:assertTrue(path.includes(string `id_list=2107.05580${encodedComma}1605.08386`));
}

@test:Config {}
function testBuildQueryPathUsesStartAndPageSize() returns error? {
    string path = check buildQueryPath({}, 50, 25);
    test:assertTrue(path.includes("start=50"));
    test:assertTrue(path.includes("max_results=25"));
}

@test:Config {}
function testBuildQueryPathSortOptions() returns error? {
    string path = check buildQueryPath({sortBy: SUBMITTED_DATE, sortOrder: ASCENDING}, 0, 10);
    test:assertTrue(path.includes("sortBy=submittedDate"));
    test:assertTrue(path.includes("sortOrder=ascending"));
}

@test:Config {}
function testGetShortIdWithMarker() {
    Result result = sampleResult("https://arxiv.org/abs/2107.05580v1");
    test:assertEquals(getShortId(result), "2107.05580v1");
}

@test:Config {}
function testGetShortIdWithoutMarker() {
    Result result = sampleResult("not-a-standard-entry-id");
    test:assertEquals(getShortId(result), "not-a-standard-entry-id");
}

@test:Config {}
function testGetShortIdFromEntryIdString() {
    test:assertEquals(getShortId("https://arxiv.org/abs/2107.05580v1"), "2107.05580v1");
}

@test:Config {}
function testGetShortIdFromEntryIdStringWithLegacyFormat() {
    test:assertEquals(getShortId("https://arxiv.org/abs/quant-ph/0201082v1"), "quant-ph/0201082v1");
}

@test:Config {}
function testGetShortIdFromEntryIdStringWithoutMarker() {
    test:assertEquals(getShortId("not-a-standard-entry-id"), "not-a-standard-entry-id");
}

@test:Config {}
function testGetSourceUrlWithPdf() {
    Result result = sampleResult("https://arxiv.org/abs/2107.05580v1");
    result.pdfUrl = "https://arxiv.org/pdf/2107.05580v1";
    test:assertEquals(getSourceUrl(result), "https://arxiv.org/src/2107.05580v1");
}

@test:Config {}
function testGetSourceUrlWithoutPdf() {
    Result result = sampleResult("https://arxiv.org/abs/2107.05580v1");
    test:assertTrue(getSourceUrl(result) is ());
}

@test:Config {}
function testGetSourceUrlWithoutPdfMarker() {
    Result result = sampleResult("https://arxiv.org/abs/2107.05580v1");
    result.pdfUrl = "https://arxiv.org/other/2107.05580v1";
    test:assertEquals(getSourceUrl(result), "https://arxiv.org/other/2107.05580v1");
}

isolated function sampleResult(string entryId) returns Result => {
    entryId,
    updated: [0, 0.0d],
    published: [0, 0.0d],
    title: "Sample",
    summary: "Sample summary",
    primaryCategory: "cs.AI"
};
