# ImageGraph package

This package provides [*Torch*](http://torch.ch/) standard functions to create and manipulate edge-weighted graphs of images: create a graph, segment it, compute its watershed, or its connected components.

## Dependencies

The [*boost*](http://www.boost.org/) library is required. You can install it with one of the following commands

``` sh
apt-get install libboost-all-dev # on Ubuntu
brew install boost               # on MacOS
```

## Installation

``` sh
luarocks install imgraph
```

## Use the library

First run *Torch*, typing `th`, and load imgraph

``` lua
require 'imgraph'
```

Once loaded, tab-completion will help you navigate through the library:

``` lua
> imgraph. + TAB
imgraph.colorize(           imgraph.connectcomponents(  
imgraph.graph(              imgraph.histpooling(        
imgraph.segmentmst(         imgraph.testme(             
imgraph.watershed(          imgraph.gradient(
```

To get quickly started, run the testme() function:

``` lua
> imgraph.testme()
```

which computes a few things on the famous image of Lena:

![results](http://data.neuflow.org/share/imgraph-testme.jpg)
