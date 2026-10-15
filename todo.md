
# short term
1. create a readme
2. create sdef folder if doent already exist
3. move code away from main function to helper functions because main is too complex
4. read all folders that contains .desktop files and mime info files instead of just /usr/share/applications
5. remove dependency on gio and cache exec commands to improve performance
6. add strings to image-viewer and pdf-viewer in mimeAppsWrite so they are used as defaults
7. improve error handling by showing user facing errors insrtead of azig errors
8. ensure no memory leaks by testing with a gpa
9. make a tag
10. add writing to DE specific 'mimeapp.list' to better support DEs
11. better source file names

# long term
1. make a gui app (the gui can simply wrap the cli instead of being a standalone)
2. make an API so desktop shells can integrate this easily (possibly only allow to use cli under the hood instead)
