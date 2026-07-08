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

import ballerina/url;

const string SERVICE_URL = "https://export.arxiv.org";
const string QUERY_PATH = "/api/query";

# Builds the request path (including the query string) for one page of the given search.
#
# + searchQuery - The search to build a request path for
# + startIndex - The 0-based index of the first result to fetch
# + pageSize - The maximum number of results to fetch in this page
# + return - The request path, or an error if a parameter value could not be URL-encoded
isolated function buildQueryPath(Search searchQuery, int startIndex, int pageSize) returns string|error {
    map<string> params = {
        "search_query": searchQuery.query,
        "id_list": string:'join(",", ...searchQuery.idList),
        "start": startIndex.toString(),
        "max_results": pageSize.toString(),
        "sortBy": searchQuery.sortBy,
        "sortOrder": searchQuery.sortOrder
    };
    string[] pairs = [];
    foreach [string, string] [name, value] in params.entries() {
        string encodedValue = check url:encode(value, "UTF-8");
        pairs.push(name + "=" + encodedValue);
    }
    return string `${QUERY_PATH}?${string:'join("&", ...pairs)}`;
}

# Returns the short arXiv identifier for a result, extracted from its `entryId`.
#
# + result - The result to extract the identifier from.
# + return - e.g. `2107.05580v1`, or the legacy `quant-ph/0201082v1` format for pre-March-2007
# identifiers.
public function getShortId(Result result) returns string {
    string marker = "arxiv.org/abs/";
    int? markerIndex = result.entryId.indexOf(marker);
    if markerIndex is () {
        return result.entryId;
    }
    return result.entryId.substring(markerIndex + marker.length());
}

# Derives the URL of the source tarball for a result from its `pdfUrl`.
#
# + result - The result to derive the source URL for.
# + return - The source URL, or `()` if the result has no PDF link.
public function getSourceUrl(Result result) returns string? {
    string? pdfUrl = result.pdfUrl;
    if pdfUrl is () {
        return ();
    }
    string marker = "/pdf/";
    int? markerIndex = pdfUrl.indexOf(marker);
    if markerIndex is () {
        return pdfUrl;
    }
    return pdfUrl.substring(0, markerIndex) + "/src/" + pdfUrl.substring(markerIndex + marker.length());
}
