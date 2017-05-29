## Core Animation Pie Chart

### Created by Brian Coyner (2011, 2012, 2013, 2017)

This demo was created to help support one of my [CocoaConf talks](http://cocoaconf.com/session/details/70). The demo
shows various techniques for building an interactive, animatable pie chart using Core Animation (`CAShapeLayer`, `CATextLayer`, `CADisplayLink`, etc.)
At the root of the solution is using a dynamic `CALayer` property to control the custom animations. The same technique can be applied to other solutions. 

### Requirements/ Features

- Xcode 8.3, iOS 10.3 

The pie chart contains theses features:

- add new slices (animated)
- remove selected slice (animated)
- update existing pie values (animated)
- interactive slice selection (tap and/ or move your finger)

The view uses a data source (number of slices, slice value) and delegate (selection tracking). 


