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

import ballerina/log;
import ballerina/time;

xmlns "http://www.w3.org/2005/Atom" as atom;
xmlns "http://arxiv.org/schemas/atom" as arxivNs;
xmlns "http://a9.com/-/spec/opensearch/1.1/" as opensearch;

# One page of parsed arXiv search results, including feed-level pagination metadata.
#
# + totalResults - The total number of results matching the search, across all pages
# + results - The results on this page
type FeedPage record {|
    int totalResults;
    Result[] results;
|};

# Parses a full arXiv API Atom response into a `FeedPage`. Entries missing required fields are
# logged and skipped rather than failing the whole page, mirroring the upstream API's tolerance
# for occasionally malformed entries.
#
# + feed - The root `<feed>` element of an arXiv API Atom response
# + return - The parsed page, or an error if a required feed-level element is malformed
isolated function parseFeed(xml feed) returns FeedPage|error {
    int totalResults = check parseIntElement(feed/<opensearch:totalResults>);
    Result[] results = [];
    foreach xml entryElement in feed/<atom:entry> {
        Result? result = check parseEntry(entryElement);
        if result is Result {
            results.push(result);
        }
    }
    return {totalResults, results};
}

isolated function parseEntry(xml entry) returns Result|error? {
    string? entryId = elementText(entry/<atom:id>);
    if entryId is () {
        log:printWarn("Skipping entry without <id>");
        return ();
    }

    string? updatedText = elementText(entry/<atom:updated>);
    string? publishedText = elementText(entry/<atom:published>);
    if updatedText is () || publishedText is () {
        log:printWarn("Skipping entry missing <updated> or <published>", entryId = entryId);
        return ();
    }
    time:Utc updated = check time:utcFromString(updatedText.trim());
    time:Utc published = check time:utcFromString(publishedText.trim());

    string? titleText = elementText(entry/<atom:title>);
    string title = titleText is string ? re `\s+`.replaceAll(titleText, " ").trim() : "";

    string? summaryText = elementText(entry/<atom:summary>);
    Link[] links = parseLinks(entry);

    return {
        entryId,
        updated,
        published,
        title,
        authors: parseAuthors(entry),
        summary: summaryText is string ? summaryText.trim() : "",
        comment: elementText(entry/<arxivNs:comment>),
        journalRef: elementText(entry/<arxivNs:journal_ref>),
        doi: elementText(entry/<arxivNs:doi>),
        primaryCategory: parsePrimaryCategory(entry),
        categories: parseCategories(entry),
        links,
        pdfUrl: getPdfUrl(links)
    };
}

isolated function parseAuthors(xml entry) returns Author[] {
    Author[] authors = [];
    foreach xml authorElement in entry/<atom:author> {
        string? nameText = elementText(authorElement/<atom:name>);
        string[] affiliations = [];
        foreach xml affiliationElement in authorElement/<arxivNs:affiliation> {
            string? affiliationText = elementText(affiliationElement);
            if affiliationText is string {
                affiliations.push(affiliationText);
            }
        }
        authors.push({name: nameText is string ? nameText : "", affiliation: affiliations});
    }
    return authors;
}

isolated function parseLinks(xml entry) returns Link[] {
    Link[] links = [];
    foreach xml:Element linkElement in entry/<atom:link> {
        map<string> attributes = linkElement.getAttributes();
        string? href = attributes["href"];
        if href is string {
            links.push({
                href,
                title: attributes["title"],
                rel: attributes["rel"] ?: "",
                contentType: attributes["type"]
            });
        }
    }
    return links;
}

isolated function parseCategories(xml entry) returns string[] {
    string[] categories = [];
    foreach xml:Element categoryElement in entry/<atom:category> {
        string? term = categoryElement.getAttributes()["term"];
        if term is string {
            categories.push(term);
        }
    }
    return categories;
}

isolated function parsePrimaryCategory(xml entry) returns string {
    xml primaryCategoryElement = entry/<arxivNs:primary_category>;
    if primaryCategoryElement.length() > 0 && primaryCategoryElement is xml:Element {
        string? term = primaryCategoryElement.getAttributes()["term"];
        return term is string ? term : "";
    }
    return "";
}

isolated function getPdfUrl(Link[] links) returns string? {
    foreach Link link in links {
        if link.title == "pdf" {
            return link.href;
        }
    }
    return ();
}

isolated function elementText(xml element) returns string? {
    if element.length() == 0 {
        return ();
    }
    return (element/*).toString();
}

isolated function parseIntElement(xml element) returns int|error {
    string? text = elementText(element);
    if text is () {
        return 0;
    }
    string trimmedText = text.trim();
    if trimmedText == "" {
        return 0;
    }
    return int:fromString(trimmedText);
}
