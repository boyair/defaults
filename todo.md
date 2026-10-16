
# short term
* create a readme
* move code away from main function to helper functions because main is too complex
* read all folders that contains .desktop files and mime info files instead of just /usr/share/applications
* remove dependency on gio and cache exec commands to improve performance
* improve error handling by showing user facing errors insrtead of zig errors
* ensure no memory leaks by testing with a gpa
* make a tag
* add writing to DE specific 'mimeapp.list' to better support DEs
* better source file names

# long term
* make a gui app (the gui can simply wrap the cli instead of being a standalone)
* make an API so desktop shells can integrate this easily (possibly only allow to use cli under the hood instead)
