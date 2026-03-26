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
    var style = document.createElement('style');
    style.textContent = '.wy-nav-content{max-width:none !important;width:100% !important;margin:0 !important;}';
    document.head.appendChild(style);
})();