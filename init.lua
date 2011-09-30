----------------------------------------------------------------------
--
-- Copyright (c) 2011 Clement Farabet
--               2006 Pedro Felzenszwalb
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
--
----------------------------------------------------------------------
-- description:
--     imgraph - a graph package for images:
--               this package contains several routines to build graphs
--               on images, and then compute their connected components,
--               watershed, min-spanning trees, and so on.
--
--               The min-spanning three based segmentation (segmentmst)
--               originates from Felzenszwalb's 2004 paper:
--               "Efficient Graph-Based Image Segmentation".
--
-- history:
--     July 14, 2011, 5:52PM  - colorizing function  - Clement Farabet
--     July 14, 2011, 12:49PM - MST + HistPooling    - Clement Farabet
--     July 13, 2011, 6:16PM  - first draft          - Clement Farabet
----------------------------------------------------------------------

require 'torch'
require 'xlua'
require 'image'

-- create global nnx table:
imgraph = {}

-- c lib:
require 'libimgraph'

----------------------------------------------------------------------
-- computes a graph from an 2D or 3D image
--
function imgraph.graph(...)
   -- get args
   local args = {...}
   local dest, img, connex, distance
   local arg2 = torch.typename(args[2])
   if arg2 and arg2:find('Tensor') then
      dest = args[1]
      img = args[2]
      connex = args[3]
      distance = args[4]
   else
      dest = torch.Tensor()
      img = args[1]
      connex = args[2]
      distance = args[3]
   end

   -- defaults
   connex = connex or 4
   distance = ((not distance) and 'e') or ((distance == 'euclid') and 'e') or ((distance == 'angle') and 'a')

   -- usage
   if not img or (connex ~= 4 and connex ~= 8) or (distance ~= 'e' and distance ~= 'a') then
      print(xlua.usage('imgraph.graph',
                       'compute an edge-weighted graph on an image', nil,
                       {type='torch.Tensor', help='input tensor (for now KxHxW or HxW)', req=true},
                       {type='number', help='connexity (edges per vertex): 4 | 8', default=4},
                       {type='string', help='distance metric: euclid | angle', req='euclid'},
                       "",
                       {type='torch.Tensor', help='destination: existing graph', req=true},
                       {type='torch.Tensor', help='input tensor (for now KxHxW or HxW)', req=true},
                       {type='number', help='connexity (edges per vertex): 4 | 8', default=4},
                       {type='string', help='distance metric: euclid | angle', req='euclid'}))
      xlua.error('incorrect arguments', 'imgraph.graph')
   end

   -- compute graph
   img.imgraph.graph(dest, img, connex, distance)

   -- return result
   return dest
end

----------------------------------------------------------------------
-- compute the connected components of a graph
--
function imgraph.connectcomponents(...)
   --get args
   local args = {...}
   local dest, graph, threshold, colorize
   if arg2 and arg2:find('Tensor') then
      dest = args[1]
      graph = args[2]
      threshold = args[3]
      colorize = args[4]
   else
      dest = torch.Tensor()
      graph = args[1]
      threshold = args[2]
      colorize = args[3]
   end

   -- defaults
   threshold = threshold or 0.5

   -- usage
   if not graph then
      print(xlua.usage('imgraph.connectcomponents',
                       'compute the connected components of an edge-weighted graph', nil,
                       {type='torch.Tensor', help='input graph', req=true},
                       {type='number', help='threshold for connecting components', default=0.5},
                       {type='boolean', help='replace components id by random colors', default=false},
                       "",
                       {type='torch.Tensor', help='destination tensor', req=true},
                       {type='torch.Tensor', help='input graph', req=true},
                       {type='number', help='threshold for connecting components', default=0.5},
                       {type='boolean', help='replace components id by random colors', default=false}))
      xlua.error('incorrect arguments', 'imgraph.connectcomponents')
   end

   -- compute image
   local nelts = graph.imgraph.connectedcomponents(dest, graph, threshold, colorize)

   -- return image
   return dest, nelts
end

----------------------------------------------------------------------
-- compute the gradient amplitude of a graph
--
function imgraph.gradient(...)
   -- get args
   local args = {...}
   local gradient, graph
   local arg2 = torch.typename(args[2])
   if arg2 and arg2:find('Tensor') then
      gradient = args[1]
      graph = args[2]
   else
      gradient = torch.Tensor()
      graph = args[1]
   end

   -- usage
   if not graph then
      print(xlua.usage('imgraph.gradient',
                       'compute an approximated gradient map of a graph\n'
                          .. 'the map has the size of the original image on which the graph\n'
                          .. 'was constructed',
                       nil,
                       {type='torch.Tensor', help='input graph', req=true},
                       "",
                       {type='torch.Tensor', help='destination tensor', req=true},
                       {type='torch.Tensor', help='input graph', req=true}))
      xlua.error('incorrect arguments', 'imgraph.gradient')
   end

   -- compute graph
   graph.imgraph.gradient(gradient, graph)

   -- return result
   return gradient
end

----------------------------------------------------------------------
-- compute the watershed of a graph
--
function imgraph.watershed(...)
   --get args
   local args = {...}
   local dest, gradient, minHeight, connex, colorize
   if arg2 and arg2:find('Tensor') then
      dest = args[1]
      gradient = args[2]
      minHeight = args[3]
      connex = args[4]
   else
      dest = torch.Tensor()
      gradient = args[1]
      minHeight = args[2]
      connex = args[3]
   end

   -- defaults
   minHeight = minHeight or 0.05
   connex = connex or 4

   -- usage
   if not gradient or (gradient:nDimension() ~= 2) then
      print(xlua.usage('imgraph.watershed',
                       'compute the watershed of a gradient map (or arbitrary grayscale image)', nil,
                       {type='torch.Tensor', help='input gradient map (HxW tensor)', req=true},
                       {type='number', help='filter minimas by imposing a minimum height', default=0.05},
                       {type='number', help='connexity: 4 | 8', default=4},
                       "",
                       {type='torch.Tensor', help='destination tensor', req=true},
                       {type='torch.Tensor', help='input gradient map (HxW tensor)', req=true},
                       {type='number', help='filter minimas by imposing a minimum height', default=0.05},
                       {type='number', help='connexity: 4 | 8', default=4}))
      xlua.error('incorrect arguments', 'imgraph.watershed')
   end

   -- compute image
   local nelts = gradient.imgraph.watershed(dest, gradient, minHeight, connex)

   -- return image
   return dest, nelts
end

----------------------------------------------------------------------
-- segment a graph, by computing its min-spanning tree and
-- merging vertices based on a dynamic threshold
--
function imgraph.segmentmst(...)
   --get args
   local args = {...}
   local dest, graph, thres, minsize, colorize
   if arg2 and arg2:find('Tensor') then
      dest = args[1]
      graph = args[2]
      thres = args[3]
      minsize = args[4]
      colorize = args[5]
   else
      dest = torch.Tensor()
      graph = args[1]
      thres = args[2]
      minsize = args[3]
      colorize = args[4]
   end

   -- defaults
   thres = thres or 3
   minsize = minsize or 20
   colorize = colorize or false

   -- usage
   if not graph then
      print(xlua.usage('imgraph.segmentmst',
                       'segment an edge-weighted graph, using a surface adaptive criterion\n'
                          .. 'on the min-spanning tree of the graph (see Felzenszwalb et al. 2004)',
                       nil,
                       {type='torch.Tensor', help='input graph', req=true},
                       {type='number', help='base threshold for merging', default=3},
                       {type='number', help='min size: merge components of smaller size', default=20},
                       {type='boolean', help='replace components id by random colors', default=false},
                       "",
                       {type='torch.Tensor', help='destination tensor', req=true},
                       {type='torch.Tensor', help='input graph', req=true},
                       {type='number', help='base threshold for merging', default=3},
                       {type='number', help='min size: merge components of smaller size', default=20},
                       {type='boolean', help='replace components id by random colors', default=false}))
      xlua.error('incorrect arguments', 'imgraph.segmentmst')
   end

   -- compute image
   local nelts = graph.imgraph.segmentmst(dest, graph, thres, minsize, colorize)

   -- return image
   return dest, nelts
end

----------------------------------------------------------------------
-- pool the features (or pixels) of an image into a segmentation map
--
function imgraph.histpooling(...)
   --get args
   local args = {...}
   local srcdest, segmentation, lists, histmax, minconfidence
   srcdest = args[1]
   segmentation = args[2]
   histmax = args[3]
   minconfidence = args[4]

   -- defaults
   histmax = histmax or false
   minconfidence = minconfidence or 0

   -- usage
   if not srcdest or not segmentation or not torch.typename(srcdest):find('Tensor') or not torch.typename(segmentation):find('Tensor') then
      print(xlua.usage('imgraph.histpooling',
                       'pool the features (or pixels) of an image into a segmentation map,\n'
                          .. 'using histogram accumulation. this is useful for colorazing a\n'
                          .. 'segmentation with the original pixel colors, or for cleaning up\n'
                          .. 'a dense prediction map.\n\n'
                          .. 'the pooling is done in place (the input is replaced)\n\n'
                          .. 'two extra lists of components are optionally generated:\n'
                          .. 'the first list is an array of these components, \n'
                          .. 'while the second is a hash table; each entry has this format:\n'
                          .. 'entry = {centroid_x, centroid_y, surface, hist_max, id}',
                       nil,
                       {type='torch.Tensor', help='input image/map/matrix to pool (must be KxHxW)', req=true},
                       {type='torch.Tensor', help='segmentation to guide pooling (must be HxW)', req=true},
                       {type='boolean', help='hist max: replace histograms by their max bin', default=false},
                       {type='number', help='min confidence: vectors with a low confidence are not accumulated', default=0}))
      xlua.error('incorrect arguments', 'imgraph.histpooling')
   end

   -- compute image
   local iresults, hresults = srcdest.imgraph.histpooling(srcdest, segmentation, 
                                                          true, histmax, minconfidence)

   -- return image
   return srcdest, iresults, hresults
end

----------------------------------------------------------------------
-- return the adjacency matrix of a segmentation map
--
function imgraph.adjacency(...)
   -- get args
   local args = {...}
   local grayscale = args[1]

   -- usage
   if not grayscale or grayscale:dim() ~= 2 then
      print(xlua.usage('imgraph.adjacency',
                       'return the adjacency matrix of a segmentation map',
                       'graph = imgraph.graph(image.lena())\n'
                          .. 'segm = imgraph.segmentmst(graph)\n'
                          .. 'matrix = imgraph.adjacency(segm)',
                       {type='torch.Tensor', help='input segmentation map (must be HxW), and each element must be in [1,NCLASSES]', req=true}))
      xlua.error('incorrect arguments', 'imgraph.adjacency')
   end

   -- support LongTensors
   if torch.typename(grayscale) == 'torch.LongTensor' then
      grayscale = torch.Tensor(grayscale:size(1), grayscale:size(2)):copy(grayscale)
   end

   -- fill matrix
   local matrix = grayscale.imgraph.adjacency(grayscale, {})

   -- return matrix
   return matrix
end

----------------------------------------------------------------------
-- extract information/geometry of a segmentation's components
--
function imgraph.extractcomponents(...)
   -- get args
   local args = {...}
   local grayscale = args[1]
   local img = args[2]

   -- usage
   if not grayscale or grayscale:dim() ~= 2 then
      print(xlua.usage('imgraph.extractcomponents',
                       'return a list of structures describing the components of a segmentation',
                       'graph = imgraph.graph(image.lena())\n'
                          .. 'segm = imgraph.segmentmst(graph)\n'
                          .. 'components = imgraph.extractcomponents(segm)',
                       {type='torch.Tensor', help='input segmentation map (must be HxW), and each element must be in [1,NCLASSES]', req=true},
                       {type='torch.Tensor', help='auxiliary image: if given, then components are cropped from it (must be KxHxW)'}))
      xlua.error('incorrect arguments', 'imgraph.extractcomponents')
   end

   -- support LongTensors
   if torch.typename(grayscale) == 'torch.LongTensor' then
      grayscale = torch.Tensor(grayscale:size(1), grayscale:size(2)):copy(grayscale)
   end

   -- generate lists
   local hcomponents = grayscale.imgraph.extractcomponents(grayscale)

   -- reorganize
   local components = {centroid_x={}, centroid_y={}, size={}, 
                       id = {}, revid = {},
                       bbox_width = {}, bbox_height = {},
                       bbox_top = {}, bbox_bottom = {}, bbox_left = {}, bbox_right = {},
                       bbox_x = {}, bbox_y = {}, patch = {}}
   local i = 0
   for _,comp in pairs(hcomponents) do
      i = i + 1
      components.centroid_x[i]  = comp[1]
      components.centroid_y[i]  = comp[2]
      components.size[i]        = comp[3]
      components.id[i]          = comp[5]
      components.revid[comp[5]] = i
      components.bbox_left[i]   = comp[6]
      components.bbox_right[i]  = comp[7]
      components.bbox_top[i]    = comp[8]
      components.bbox_bottom[i] = comp[9]
      components.bbox_width[i]  = comp[10]
      components.bbox_height[i] = comp[11]
      components.bbox_x[i]      = comp[12]
      components.bbox_y[i]      = comp[13]
   end
   components.size = function(self) return #self.id end

   -- auxiliary image given ?
   if img and img:nDimension() == 3 then
      local c = components
      for k = 1,i do
         local top = c.bbox_top[k]
         local height = c.bbox_height[k]
         local left = c.bbox_left[k]
         local width = c.bbox_width[k]
         c.patch[k] = img:narrow(2,top,height):narrow(3,left,width)
      end
   end

   -- return both lists
   return components
end

----------------------------------------------------------------------
-- colorize a segmentation map
--
function imgraph.colorize(...)
   -- get args
   local args = {...}
   local grayscale = args[1]
   local colormap = args[2] or torch.Tensor()
   local colorized = torch.Tensor()

   -- usage
   if not grayscale or grayscale:dim() ~= 2 then
      print(xlua.usage('imgraph.colorize',
                       'colorize a segmentation map',
                       'graph = imgraph.graph(image.lena())\n'
                          .. 'segm = imgraph.segmentmst(graph)\n'
                          .. 'colored = imgraph.colorize(segm)',
                       {type='torch.Tensor', help='input segmentation map (must be HxW), and each element must be in [1,width*height]', req=true},
                       {type='torch.Tensor', help='color map (must be Nx3), if not provided, auto generated'}))
      xlua.error('incorrect arguments', 'imgraph.colorize')
   end

   -- support LongTensors
   if torch.typename(grayscale) == 'torch.LongTensor' then
      grayscale = torch.Tensor(grayscale:size(1), grayscale:size(2)):copy(grayscale)
   end

   -- colorize !
   grayscale.imgraph.colorize(colorized, grayscale, colormap)

   -- return colorized segmentation
   return colorized, colormap
end

----------------------------------------------------------------------
-- create a color map from a table
--
function imgraph.colormap(colors, verbose)
   -- usage
   if not colors then
      print(xlua.usage('imgraph.colormap',
                       'create a color map, from a table {id1={r,g,b}, id2={r,g,b}, ...}', nil,
                       {type='table', help='a table of RGB triplets', req=true},
                       {type='boolean', help='verbose', default=false}))
      xlua.error('incorrect arguments', 'imgraph.colormap')
   end

   -- found max in table
   local max = -1/0
   for k,entry in pairs(colors) do
      if k > max then max = k end
   end

   -- make map
   local nentries = max+1
   if verbose then print('<imgraph.colormap> creating map with ' .. nentries .. ' entries') end
   local colormap = torch.Tensor(nentries, 3):fill(-1)
   for k,color in pairs(colors) do
      local c = colormap[k+1]
      c[1] = color[1]; c[2] = color[2]; c[3] = color[3]
   end

   -- return color map
   return colormap
end

----------------------------------------------------------------------
-- a simple test me function
--
imgraph._example = [[
      -- (1) load an image & compute its graph
      local lena = image.lena()
      local lenag = image.convolve(lena, image.gaussian(3), 'full')
      local graph = imgraph.graph(lenag)

      -- (2) compute its connected components, and mst segmentation
      local cc = imgraph.connectcomponents(graph, 0.1, true)
      local mstsegm = imgraph.segmentmst(graph, 3, 20)
      local mstsegmcolor = imgraph.colorize(mstsegm)

      -- (3) do a histogram pooling of the original image:
      local pool = imgraph.histpooling(lena, mstsegm)

      -- (4) compute the watershed of the graph
      local graph = imgraph.graph(lenag, 8)
      local gradient = imgraph.gradient(graph)
      local watershed = imgraph.watershed(gradient, 0.07, 8)
      local watershedgraph = imgraph.graph(watershed, 8)
      local watershedcc = imgraph.connectcomponents(watershedgraph, 0.5, true)

      -- (5) display results
      image.display{image=image.lena(), legend='input image'}
      image.display{image=graph, legend='left: horizontal edges, right: vertical edges'}
      image.display{image=cc, legend='thresholded graph'}
      image.display{image=watershed, legend='watershed on the graph'}
      image.display{image=watershedcc, legend='components of watershed'}
      image.display{image=mstsegmcolor, legend='segmented graph, using min-spanning tree'}
      image.display{image=pool, legend='original imaged hist-pooled by segmentation'}
]]
function imgraph.testme()
   local example = loadstring(imgraph._example)
   print 'imgraph sample code {\n'
   print (imgraph._example)
   print '}'
   example()
end
