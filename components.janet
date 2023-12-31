(use joy)
(use time)
(use ./utils)
(use judge)
(import ./taskwarrior :as task)


#####################
#   Project picker  #
#####################

(def button-div-style "display: flex; flex-wrap: wrap; justify-content: flex-start;")
(def button-style "padding: 8px 30px; flex: none; width: auto; margin-right: 5px;")

(defn project-picker [current & flags]
  """
  current: string
  example: \"arch.testing\"

  Pick a project from a list of projects.

  Should be used inside a form, as it will populate an input field.

  optional flags: :only-pending
  """
  (let [only-pending     (if (empty? flags) false (contains? :only-pending flags))
        current-projects (->> (string/split "." current)
                              (filter |(not (empty? $))))
        projects         (task/get-next-level-projects current)
        flags-query      (if (empty? flags) "" (string "?flags=" (string/join (map string flags) ",")))]
    [:div {:id "project-picker"}
     [:input {:type "hidden" :name "project" :value current}]
     [:p (string "Project: " current)]

     # Subtracting sub project
     [:div {:style button-div-style}
        (meach p current-projects
         [:button {:class "primary"
                   :style button-style
                   :hx-get (string "/components/project-picker/" (-> (take-until |(= p $) current-projects)
                                                                     (string/join ".")
                                                                     (http/url-encode)) flags-query)
                   :hx-target "#project-picker"
                   :hx-trigger "click"} p])]

     # Adding sub project
     [:div {:style button-div-style}
        (meach p projects
         [:button {:class "secondary"
                   :style button-style
                   :hx-get (string "/components/project-picker/" (-> (cond
                                                                       (= "" current) p
                                                                       (string current "." p))
                                                                     (http/url-encode)) flags-query)
                   :hx-target "#project-picker"
                   :hx-trigger "click"} p])]]))

(defn project-picker-handler [req]
  (let [project (get-in req [:params :project])
        flags   (get-in req [:query-string :flags] "")]
    (text/html
      (project-picker (http/url-decode project) ;(map keyword (string/split "," flags))))))


(comment
  (def flags [:only-pending])

  (if (empty? flags) "" (string "?flags=" (string/join (map string flags) ","))))
    

##################
#   Date picker  #
##################

(defn date-picker [name current-date]
  """
  Pick a date from some common options.

  Should be used inside a form, as it will populate an input field.

  current-date could be nil, in which case the current date will be used.
  """
  (let [{:month-day d
         :month m
         :year y} (cond
                    (nil? current-date) (os/date (os/time) :local)
                    (os/date (time/parse "%Y%m%dT%H%M%S%z" current-date "UTC") :local))
        current (string y "-" (with-zero (+ 1 m)) "-" (with-zero (+ 1 d)))]
    [:div
     [:label {:for name} (string name ":")]
     [:input {:type "date"
              :id name
              :name name
              :value (if (nil? current-date) "" current)}]]))


##########################
#   Custom input button  #
##########################

(defn custom-input-button-handler [req]
  (text/html
    [:input {:type "text" :name "modify"} ""]
    [:button {:type "submit"} "Modify"]))

(defn custom-input-button [id]
  [:button {:class "secondary"
            :style "float: left; width: 200px; font-size: 12px;"
            :hx-get "/components/custom-input-button"
            :hx-target (string "#" id)
            :hx-swap "innerHTML"}
    "Custom input"])
  
