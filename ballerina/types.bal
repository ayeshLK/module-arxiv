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

import ballerina/time;

# The criteria by which arXiv search results can be sorted.
public enum SortCriterion {
    RELEVANCE = "relevance",
    LAST_UPDATED_DATE = "lastUpdatedDate",
    SUBMITTED_DATE = "submittedDate"
}

# The order in which sorted search results are returned.
public enum SortOrder {
    ASCENDING = "ascending",
    DESCENDING = "descending"
}

# An author of an arXiv paper.
public type Author record {|
    # The author's name.
    string name;
    # Any `<arxiv:affiliation>` values associated with this author. Most results have no
    # affiliation data, in which case this is an empty array.
    string[] affiliation = [];
|};

# A link associated with a search result, e.g. the abstract page, the PDF, or a DOI.
public type Link record {|
    # The link's `href` attribute.
    string href;
    # The link's title, e.g. `"pdf"` or `"doi"`. Not every link has a title.
    string? title = ();
    # The link's relationship to the result, e.g. `"alternate"` or `"related"`.
    string rel = "";
    # The link's HTTP content type, e.g. `"application/pdf"`. Not every link has one.
    string? contentType = ();
|};

# A single entry in an arXiv search results feed.
#
# See [the arXiv API User's Manual: Details of Atom Results Returned](https://info.arxiv.org/help/api/user-manual.html#_details_of_atom_results_returned).
public type Result record {|
    # A URL of the form `https://arxiv.org/abs/{id}`.
    string entryId;
    # When the result was last updated.
    time:Utc updated;
    # When the result was originally published.
    time:Utc published;
    # The title of the result.
    string title;
    # The result's authors.
    Author[] authors = [];
    # The result abstract.
    string summary;
    # The authors' comment, if present.
    string? comment = ();
    # A journal reference, if present.
    string? journalRef = ();
    # A URL for the resolved DOI to an external resource, if present.
    string? doi = ();
    # The result's primary arXiv category. See [arXiv Category Taxonomy](https://arxiv.org/category_taxonomy).
    string primaryCategory;
    # All of the result's categories.
    string[] categories = [];
    # Up to three URLs associated with this result.
    Link[] links = [];
    # The URL of a PDF version of this result, if present among `links`.
    string? pdfUrl = ();
|};

# A specification for a search of arXiv's database.
public type Search record {|
    # A query string, e.g. `au:del_maestro AND ti:checkerboard`. Should be unencoded — do not
    # pre-encode spaces or special characters.
    #
    # See [the arXiv API User's Manual: Details of Query Construction](https://info.arxiv.org/help/api/user-manual.html#query_details).
    string query = "";
    # A list of arXiv article IDs to limit the search to. See the arXiv API User's Manual for the
    # interaction between `query` and `idList`.
    string[] idList = [];
    # The maximum number of results to return for this search. Set to `()` to fetch every
    # available result. The API's limit is 300,000 results per query.
    int? maxResults = 100;
    # The sort criterion for results.
    SortCriterion sortBy = RELEVANCE;
    # The sort order for results.
    SortOrder sortOrder = DESCENDING;
|};
