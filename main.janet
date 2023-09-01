(use joy)
(import ./taskwarrior :as task)
(import ./git :as git)


# Layout
(defn app-layout [{:body body :request request}]
  (text/html
    (doctype :html5)
    [:html {:lang "en"}
     [:head
      [:title "taskwarriorweb"]
      [:meta {:charset "utf-8"}]
      [:meta {:name "viewport" :content "width=device-width, initial-scale=1"}]
      [:meta {:name "csrf-token" :content (csrf-token-value request)}]
      [:link {:href "/app.css" :rel "stylesheet"}]
      [:link {:href "https://cdn.jsdelivr.net/npm/@picocss/pico@1/css/pico.min.css" :rel "stylesheet"}]
      [:script {:src "/app.js" :defer ""}]
      [:script {:src "https://unpkg.com/htmx.org@1.9.5"}]]
     [:body
       body]]))


# Routes
(route :get "/" :home)
(route :get "/git-status" :git-status)
(route :post "/git-pull" :git-pull)
(route :post "/git-push" :git-push)

(defn to-list [items]
  (map (fn [item]
         (pp item)
         [:li (get item :description)])
       items))

(defn display-time [t]
  (string "TODO"))

(defn display-project [p]
  (string/replace-all "." " " p))

(defn to-table [items]
  (let [rows (map (fn [{:description desc
                        :project p
                        :urgency u
                        :due due
                        :sceduled sch
                        :uuid uuid}]
                      [:tr
                         [:td desc]
                         [:td p]
                         [:td (display-time due)]
                         [:td (display-time sch)]
                         [:td (math/floor u)]
                         [:td [:a {:href (string "/edit/" uuid)} "edit"]]])
                  items)]
    [:table {:role "grid"}
      [:thead
       [:tr
         [:th "Description"]
         [:th "Project"]
         [:th "Due"]
         [:th "Scheduled"]
         [:th "Urgency"]
         [:th "edit"]]]
      [:tbody rows]]))

(defn git-status-wrapper [content]
  [:div {:style "float: right; height: 50px; margin: 10px;" :id "git-status"}
    content])
  
(defn to-table-mobile [items]
  "Only showing description and project"
  (let [rows (map (fn [{:description desc
                        :project p
                        :urgency u
                        :due due
                        :sceduled sch
                        :uuid uuid}]
                      [:tr {:hx-get (string "/open/" uuid)}
                         [:td desc]
                         [:td {:style "white-space: pre-line"} (display-project p)]
                         [:td (math/floor u)]])
                  items)]
    [:table {:role "grid"}
      [:thead
       [:tr
         [:th "Description"]
         [:th "Project"]
         [:th ""]]]
      [:tbody rows]]))

(defn home [request]
  (let [today (task/get-today)]
    [:main
      (git-status-wrapper
         [:span {:hx-get "/git-status" :hx-trigger "load"} "⚪"])
      [:h1 "Today"]
      (to-table-mobile today)
      [:p {:class "code"}
        [:p (string "showing " (length today) " tasks")]]]))
        
(defn git-status [request]
  (-> (git/get-status) (git/show-status)))

(defn git-pull [request]
  (git/show-status {:remote? false :local? false}))

(defn git-push [request]
  (let [[success value] (-> (git/push-changes) (protect)) # What should we do with the a failed value?
        status (git/get-status)]
    (git/show-status status)))

# Middleware
(def app (-> (handler)
             (layout app-layout)
             (with-session)
             (extra-methods)
             (query-string)
             (body-parser)
             (json-body-parser)
             (server-error)
             (x-headers)
             (static-files)
             (not-found)
             (logger)))


# Server
(defn main [& args]
  (let [port (get args 1 (os/getenv "PORT" "9001"))
        host (get args 2 (os/getenv "HOST" "localhost"))]
    (print "Starting server on " host ":" port)
    (server app port host)))
