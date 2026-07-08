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

// Smoke tests against the real arXiv API. Excluded by default (see the root build.gradle, which
// passes `--disable-groups live` unless `-Pgroups=live` is given) since they are slow, depend on
// network access, and can't exercise error/retry paths on demand. Run them with:
//   ./gradlew test -Pgroups=live
// or, directly with the Ballerina tool, from the `ballerina` directory:
//   bal test --groups live

@test:Config {groups: ["live"]}
function testLiveSearchByKnownId() returns error? {
    // arXiv's first submission under the modern identifier scheme; a stable fixture used in
    // arXiv's own API documentation, so this result is never expected to disappear or change.
    Client liveClient = check new (numRetries = 2);
    stream<Result, error?> results = liveClient->search({idList: ["0704.0001"]});
    Result[] collected = check from Result r in results
        select r;

    test:assertEquals(collected.length(), 1);
    Result 'result = collected[0];
    test:assertTrue('result.title.length() > 0);
    test:assertTrue('result.authors.length() > 0);
    // Not asserting an exact version suffix (e.g. "v1") since papers can be revised over time.
    test:assertTrue(getShortId('result).startsWith("0704.0001v"));
    test:assertTrue('result.pdfUrl is string);
}

@test:Config {groups: ["live"]}
function testLiveSearchByQuery() returns error? {
    Client liveClient = check new (numRetries = 2);
    stream<Result, error?> results = liveClient->search({
        query: "au:del_maestro AND ti:checkerboard",
        maxResults: 3
    });
    Result[] collected = check from Result r in results
        select r;

    test:assertTrue(collected.length() > 0);
    test:assertTrue(collected.length() <= 3);
    foreach Result 'result in collected {
        test:assertTrue('result.title.length() > 0);
        test:assertTrue('result.entryId.length() > 0);
    }
}
