# Kinetic Scroll

This project provides a kinetic scroll for webkit-based browser that mimics iOS one. Key difference from all similar projects out there lies in the fact that this one uses canvas to render scroll itself. Canvas approach has to advantages:

1. there's no need to include any scroll styles or images;
2. it allows more precise rendering of the scroll in hi-dpi mode.

## Basic usage

Assuming that you have following structure of the the scrollable element:

    <div id="wrapper">
      <div id="content">
      …
      </div>
    </div>

You just need to pass a wrapper node to kinetic scroll constructor:

    new KineticScroll(document.getElementById('wrapper'));

It's necessary to have inner element encapsulating all the content (`#content` in this case) because this is what actually moves when you scroll the page.

## Configuration

Options hash can be passed as optional second argument to the constructor containing any of the following properties:

- `vertical` — (default `true`) allow vertical scroll. 
- `verticalBar` — (default `true`) show vertical scroll bar when scrolling.
- `horizontal` — (default `false`) allow horizontal scroll.
- `horizontalBar` — (default `false`) show horizontal scroll bar when scrolling.
- `ignoredSelector` — (default `"input, textarea, select"`) determines touching which elements doesn't trigger scroll.
- `paginated` — (default `false`) enables paginated scroll; direction is determined based on previous options.
- `onPageCountChange` — (default `null`) callback for page count change when in paginated mode. It's also called right after constructing scroll allowing you to build page indicator if necessary.
- `onCurrentPageChange` — (default `null`) callback for current page change. Only used in paginated mode.

To see the demo download or clone this repo and open `index.html` in a Webkit-based browser (like **Google Chrome** or **Safari**).

## License

Copyright (c) 2012 [Dmitriy Kubyshkin](kubyshkin.ru)

Dual licensed under the MIT and GPL licenses:
http://www.opensource.org/licenses/mit-license.php
http://www.gnu.org/licenses/gpl.html