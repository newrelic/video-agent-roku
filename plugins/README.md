# HTTP Sender Plugin

The HTTP Sender Plugin is a module designed to record `HTTP_REQUEST` and `HTTP_RESPONSE` events in a buffer, separated from the NRAgent, and syncronize with NRAgent at any point, whenever it's ready.

It doesn't require the NRAgent to be present for normal operation, except for the moment of syncronization.

## Installation

Import the following files into your project:

```
components/NewRelicAgent/plugins
	HttpSender.brs
	HttpSender.xml
source/plugins
	HttpSenderWrapper.brs
```

## Usage

This module consists of two parts, a Node component (files `HttpSender.xml` and `HttpSender.brs`) and a wrapper (file `HttpSenderWrapper.brs`).

The wrapper contains the functions we will actually call to operate with the plugin.

First we need to init the plugin:

```
m.plugin = nrPluginHttpSenderInit()
```

The resulting `m.plugin` is an object that contains the Node component. With this object we can call the rest of functions.

To create a domains substitution rule:

```
nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^www\.google\.com$", "Google COM")
```

To send an HTTP_REQUEST event:

```
nrPluginHttpSenderRequest(m.plugin, urlReq)
```

To send an HTTP_RESPONSE event:

```
nrPluginHttpSenderResponse(m.plugin, url, msg)
```

And finally to sync events with the New Relic Agent, we need the NRAgent object:

```
nrPluginHttpSenderSync(m.plugin, m.nr)
```

The file `components/SearchTask.brs` contains a complete usage example.
