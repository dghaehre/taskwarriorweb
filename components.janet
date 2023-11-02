(use joy)
(use time)
(use ./utils)
(import ./taskwarrior :as task)


#####################
#   Project picker  #
#####################

(defn project-picker [&opt current]
  """
  current: string
  example: \"arch.testing\"

  Pick a project from a list of projects.

  Should be used inside a form, as it will populate an input field.
  """
  (default current "")
  (let [current-projects (string/split "." current)
        projects (task/get-next-level-projects current)]
    [[:div (meach p current-projects
            [:button p])]
     [:div (meach p projects
             [:button p])]]))

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
        current (string y "-" (with-zero (+ 1 m)) "-" (with-zero (+ 1 d)))
        min-date (string y "-01-01")
        max-date (string y "-12-31")]
    [:div
     [:label {:for name} (string name ":")]
     [:input {:type "date"
              :id name
              :name name
              :value (if (nil? current-date) "" current)
              :min min-date
              :max max-date}]]))


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
  
