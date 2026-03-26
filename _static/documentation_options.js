const DOCUMENTATION_OPTIONS = {
    VERSION: '',
    LANGUAGE: 'en',
    COLLAPSE_INDEX: false,
    BUILDER: 'html',
    FILE_SUFFIX: '.html',
    LINK_SUFFIX: '.html',
    HAS_SOURCE: true,
    SOURCELINK_SUFFIX: '.txt',
    NAVIGATION_WITH_KEYS: false,
    SHOW_SEARCH_SUMMARY: true,
    ENABLE_SEARCH_SHORTCUTS: true,
};

(function () {
    var root = document.documentElement.dataset.content_root || './';
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.href = root + '_static/custom-wide.css';
    document.head.appendChild(link);
})();