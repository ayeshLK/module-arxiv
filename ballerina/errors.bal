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

# The detail record carried by every error raised while fetching a page of search results.
public type ErrorDetail record {|
    # The feed URL that could not be fetched.
    string url;
    # The request try number on which this error occurred; 0 for the initial try.
    int retryCount;
|};

# The detail record carried by an `HttpError`.
public type HttpErrorDetail record {|
    *ErrorDetail;
    # The HTTP status code returned by the API.
    int statusCode;
|};

# Raised when a page request returns a non-200 HTTP status after all retries are exhausted.
public type HttpError distinct error<HttpErrorDetail>;

# Raised when a page of results that should be non-empty is unexpectedly empty, after all
# retries are exhausted. This can happen sporadically due to brittleness in the underlying
# arXiv API and usually resolves itself on a subsequent attempt.
public type EmptyPageError distinct error<ErrorDetail>;

# The union of all errors this client can return while fetching search results.
public type ArxivError HttpError|EmptyPageError;
