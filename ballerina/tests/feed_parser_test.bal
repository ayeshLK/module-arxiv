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

function sampleEntryXml(string id, string title = "Sample Title") returns string {
    return string `<entry xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">
        <id>https://arxiv.org/abs/${id}</id>
        <updated>2020-01-01T00:00:00Z</updated>
        <published>2019-12-25T00:00:00Z</published>
        <title>  ${title}  with   extra   spaces </title>
        <summary>  A summary.  </summary>
        <arxiv:comment>5 pages</arxiv:comment>
        <arxiv:journal_ref>Some Journal 2020</arxiv:journal_ref>
        <arxiv:doi>10.1000/example</arxiv:doi>
        <author><name>Alice</name><arxiv:affiliation>MIT</arxiv:affiliation></author>
        <author><name>Bob</name></author>
        <arxiv:primary_category term="cs.LG"/>
        <category term="cs.LG"/>
        <category term="cs.AI"/>
        <link href="https://arxiv.org/abs/${id}" rel="alternate" type="text/html"/>
        <link title="pdf" href="https://arxiv.org/pdf/${id}" rel="related" type="application/pdf"/>
    </entry>`;
}

@test:Config {}
function testParseEntryFull() returns error? {
    xml entry = check xml:fromString(sampleEntryXml("2101.00001v1"));
    Result? result = check parseEntry(entry);
    if result !is Result {
        test:assertFail("expected a parsed result");
    }
    test:assertEquals(result.entryId, "https://arxiv.org/abs/2101.00001v1");
    test:assertEquals(result.title, "Sample Title with extra spaces");
    test:assertEquals(result.summary, "A summary.");
    test:assertEquals(result.comment, "5 pages");
    test:assertEquals(result.journalRef, "Some Journal 2020");
    test:assertEquals(result.doi, "10.1000/example");
    test:assertEquals(result.updated, check time:utcFromString("2020-01-01T00:00:00Z"));
    test:assertEquals(result.published, check time:utcFromString("2019-12-25T00:00:00Z"));
    test:assertEquals(result.authors.length(), 2);
    test:assertEquals(result.authors[0].name, "Alice");
    test:assertEquals(result.authors[0].affiliation, ["MIT"]);
    test:assertEquals(result.authors[1].name, "Bob");
    test:assertEquals(result.authors[1].affiliation, []);
    test:assertEquals(result.primaryCategory, "cs.LG");
    test:assertEquals(result.categories, ["cs.LG", "cs.AI"]);
    test:assertEquals(result.pdfUrl, "https://arxiv.org/pdf/2101.00001v1");
}

@test:Config {}
function testParseEntryMissingId() returns error? {
    xml entry = check xml:fromString(string `<entry xmlns="http://www.w3.org/2005/Atom">
        <updated>2020-01-01T00:00:00Z</updated>
        <published>2020-01-01T00:00:00Z</published>
        <title>No Id</title>
    </entry>`);
    Result? result = check parseEntry(entry);
    test:assertTrue(result is ());
}

@test:Config {}
function testParseEntryMissingUpdated() returns error? {
    xml entry = check xml:fromString(string `<entry xmlns="http://www.w3.org/2005/Atom">
        <id>https://arxiv.org/abs/9999.00000v1</id>
        <published>2020-01-01T00:00:00Z</published>
        <title>No Updated</title>
    </entry>`);
    Result? result = check parseEntry(entry);
    test:assertTrue(result is ());
}

@test:Config {}
function testParseEntryMissingPublished() returns error? {
    xml entry = check xml:fromString(string `<entry xmlns="http://www.w3.org/2005/Atom">
        <id>https://arxiv.org/abs/9999.00000v1</id>
        <updated>2020-01-01T00:00:00Z</updated>
        <title>No Published</title>
    </entry>`);
    Result? result = check parseEntry(entry);
    test:assertTrue(result is ());
}

@test:Config {}
function testParseEntryMinimalFields() returns error? {
    xml entry = check xml:fromString(string `<entry xmlns="http://www.w3.org/2005/Atom">
        <id>https://arxiv.org/abs/1</id>
        <updated>2020-01-01T00:00:00Z</updated>
        <published>2020-01-01T00:00:00Z</published>
    </entry>`);
    Result? result = check parseEntry(entry);
    if result !is Result {
        test:assertFail("expected a parsed result");
    }
    test:assertEquals(result.title, "");
    test:assertEquals(result.summary, "");
    test:assertEquals(result.comment, ());
    test:assertEquals(result.journalRef, ());
    test:assertEquals(result.doi, ());
    test:assertEquals(result.primaryCategory, "");
    test:assertEquals(result.categories, []);
    test:assertEquals(result.authors, []);
    test:assertEquals(result.links, []);
    test:assertEquals(result.pdfUrl, ());
}

@test:Config {}
function testParseFeedSkipsMalformedEntries() returns error? {
    string feedXml = string `<?xml version="1.0"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
        <opensearch:totalResults>2</opensearch:totalResults>
        ${sampleEntryXml("1000.00001v1")}
        <entry xmlns="http://www.w3.org/2005/Atom"><title>Missing id/updated/published</title></entry>
    </feed>`;
    xml feed = check xml:fromString(feedXml);
    FeedPage page = check parseFeed(feed);
    test:assertEquals(page.totalResults, 2);
    test:assertEquals(page.results.length(), 1);
    test:assertEquals(page.results[0].entryId, "https://arxiv.org/abs/1000.00001v1");
}

@test:Config {}
function testParseFeedEmpty() returns error? {
    string feedXml = string `<?xml version="1.0"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
        <opensearch:totalResults></opensearch:totalResults>
    </feed>`;
    xml feed = check xml:fromString(feedXml);
    FeedPage page = check parseFeed(feed);
    test:assertEquals(page.totalResults, 0);
    test:assertEquals(page.results, []);
}

@test:Config {}
function testGetPdfUrlFound() {
    Link[] links = [
        {href: "https://arxiv.org/abs/1", rel: "alternate"},
        {href: "https://arxiv.org/pdf/1", title: "pdf", rel: "related"}
    ];
    test:assertEquals(getPdfUrl(links), "https://arxiv.org/pdf/1");
}

@test:Config {}
function testGetPdfUrlNotFound() {
    Link[] links = [{href: "https://arxiv.org/abs/1", rel: "alternate"}];
    test:assertTrue(getPdfUrl(links) is ());
}

@test:Config {}
function testParseIntElementValid() returns error? {
    xml elem = check xml:fromString(
        "<opensearch:totalResults xmlns:opensearch=\"http://a9.com/-/spec/opensearch/1.1/\">42</opensearch:totalResults>"
    );
    int result = check parseIntElement(elem);
    test:assertEquals(result, 42);
}

@test:Config {}
function testParseIntElementBlank() returns error? {
    xml elem = check xml:fromString(
        "<opensearch:totalResults xmlns:opensearch=\"http://a9.com/-/spec/opensearch/1.1/\">   </opensearch:totalResults>"
    );
    int result = check parseIntElement(elem);
    test:assertEquals(result, 0);
}

@test:Config {}
function testParseIntElementInvalid() returns error? {
    xml elem = check xml:fromString(
        "<opensearch:totalResults xmlns:opensearch=\"http://a9.com/-/spec/opensearch/1.1/\">not-a-number</opensearch:totalResults>"
    );
    int|error result = parseIntElement(elem);
    test:assertTrue(result is error);
}
