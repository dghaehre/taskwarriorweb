(use joy)
(import json)
(import ./taskwarrior :as task)

# TODO: add graph based on project!
# I think maybe we should put the sql stuff in here. It is so tightly coupled

(defn- create-chart [data labels]
  [:script (raw (string "
const data = {
  labels: " (json/encode labels) ",
  datasets: [{
   data: " (json/encode data) ",
   label: 'completed',
   backgroundColor: 'rgb(255, 99, 132)',
   borderColor: 'rgb(255, 99, 132)'
  }]
};

const config = {
  type: 'line',
  data: data,
  options: {}
};

const myChart = new Chart(
  document.getElementById('chart'),
  config
);"))])

(defn- create-labels [data]
  (def {:year-day today} (os/date))
  (defn create-label [items]
    (let [day (-> (get items 0 {:day 0})
                  (get :day))]
      (cond
        (= today day) "today"
        (= today (inc day)) "yesterday"
        "")))
  (map create-label data))
  
(defn to-numbers [data]
  (map |(length $) data))

(defn completed-last-seven-days []
  (let [data (task/get-last-seven-days)]
    # (assert (= 7 (length data)))
    (let [labels (create-labels data)
          numbers (to-numbers data)]
      [[:script {:src "/xxx.chart.js"}]
       [:h4 "last seven days "
          [:small (string " (" (sum numbers) ")")]]
       [:canvas {:id "chart"}]
       (create-chart numbers labels)])))

