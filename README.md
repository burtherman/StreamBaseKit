# StreamBaseKit
Swift library for composing reactive streams with Firebase

This is a full-featured library for interfacing iOS apps with Firebase storage.  It supports basic functionality like keeping a table view synched with a firebase collection.  It also supports some more advanced features like...
* Inverted streams (critical for messaging apps)
* Support for placeholders like "fetch more" and "new since last visit"
* Incremental fetching ("fetch more")
* Union streams for merging results (eg you want to show recent and high priority content)
* Partitioned streams for splitting results into tableview sections

# Comparison with FirebaseUI-iOS
