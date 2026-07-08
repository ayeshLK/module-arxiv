# Ballerina arXiv connector

[![Build](https://github.com/ayeshLK/module-arxiv/actions/workflows/ci.yml/badge.svg)](https://github.com/ayeshLK/module-arxiv/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ayeshLK/module-arxiv.svg)](https://github.com/ayeshLK/module-arxiv/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ayeshLK/module-arxiv.svg?label=Open%20Issues)](https://github.com/ayeshLK/module-arxiv/issues)

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

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Export a GitHub personal access token with read package permissions as follows:

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

   This runs the offline suite only (unit tests plus a local mock of the arXiv API). A small
   smoke-test suite that calls the real arXiv API is excluded by default; run it explicitly with:

   ```bash
   ./gradlew clean test -Pgroups=live
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

5. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`arxiv` package](https://central.ballerina.io/ayesha/arxiv/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
