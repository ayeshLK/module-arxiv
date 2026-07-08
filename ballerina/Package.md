## Overview

[arXiv](https://arxiv.org/) is a free distribution service and an open-access archive hosting over two million scholarly articles in physics, mathematics, computer science, and related fields. Its [API](https://info.arxiv.org/help/api/index.html) lets you search this archive and returns matches as an Atom XML feed.

The Ballerina arXiv connector lets you search arXiv's database from a Ballerina application without dealing with the feed format directly. It paginates through results on your behalf, encodes query parameters, and parses each entry into typed Ballerina records, while enforcing a request rate and page size that comply with arXiv's [API Terms of Use](https://info.arxiv.org/help/api/tou.html).

> Thank you to arXiv for use of its open access interoperability. This connector was not reviewed or approved by, nor does it necessarily express or reflect the policies or opinions of, arXiv.

### Key features

- Search by free-text query, field-restricted query (e.g. `au:`, `ti:`, `cat:`), or a list of arXiv IDs
- Results are returned as a lazily-fetched `stream`, so pages are only requested as they are consumed
- Configurable page size, inter-request delay, and retry count, defaulting to values that respect arXiv's rate limits
- Typed `Result` records with authors, categories, links, DOI, and PDF/source URLs already parsed out of the feed

## Setup guide

The arXiv API is free and public. No account, registration, or API key is required to use this connector.

## Quickstart

To use the `arxiv` connector in your Ballerina application, follow these steps:

### Step 1: Import the connector

Import the `ayesha/arxiv` package into your Ballerina project.

```ballerina
import ayesha/arxiv;
```

### Step 2: Instantiate a new connector

Create an `arxiv:Client`. No configuration is required to get started with the defaults.

```ballerina
arxiv:Client arxivClient = check new ();
```

### Step 3: Invoke the connector operation

Now, utilize the available connector operations.

#### Search papers by query

```ballerina
stream<arxiv:Result, error?> results = arxivClient->search({
    query: "au:del_maestro AND ti:checkerboard",
    maxResults: 5
});

check results.forEach(function(arxiv:Result result) {
    io:println(result.title, " - ", arxiv:getShortId(result));
});
```

#### Fetch specific papers by ID

```ballerina
stream<arxiv:Result, error?> results = arxivClient->search({
    idList: ["2107.05580", "1605.08386"]
});
```
