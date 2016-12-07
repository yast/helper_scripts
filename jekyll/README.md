
# The Blog Posts Importer

This is an importer script for importing the YaST posts from https://lizards.opensuse.org/
into the blog based on Jekyll which uses the Markdown format.

# Pre-requisites

- Ruby
- Bundler (`zypper in 'rubygem(bundler)'`)

# The Process

The convertor uses the patched RSS feed importer (http://import.jekyllrb.com/docs/rss/).
The posts are extracted from the RSS feed.

However, the feed contains only few latest posts, fortunately the older feeds
can be found in the Web archive at http://web.archive.org/web/*/https://lizards.opensuse.org/feed/
But some posts are missing in the feeds as the Web Archiver archived
the feed only few times in the history, therefore the missing posts are
imported directly from a saved lizards.o.o. HTML page.

All needed posts to import are stored locally in the `feed*.xml` and
`page2.html` files.

# Starting the Import

```
bundle install --path .vendor/bundle
bundle exec ruby ./lizards_importer.rb
```

The converted posts are saved into `_posts` directory, the downloaded images
to `images` directory.

The imported posts still need some manual fine tuning (enable syntax
highlighting, fix not converted HTML tags, fix the links pointing to
lizards.o.o., ...).