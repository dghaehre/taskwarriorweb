(declare-project
  :name "taskwarriorweb"
  :description ""
  :dependencies [{:url "https://github.com/dghaehre/janet-time" :tag "50d5513585187728c7137fa681cf9af7f5e9528c"}
                 {:url "https://github.com/ianthehenry/judge.git" :tag "v2.4.0"}
                 {:url "https://github.com/joy-framework/joy"}
                 {:url "https://github.com/andrewchambers/janet-sh.git"}]
  :author ""
  :license ""
  :url ""
  :repo "")

(phony "server" []
  (os/shell "janet main.janet"))

(declare-executable
  :name "app"
  :entry "main.janet")
