(use joy)
(import json)

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

(defn- create-labels []
  "TODO"
  ["ma" "ti" "on" "to" "fr" "lø" "sø"])
  

(defn completed [data]
  (assert (= 7 (length data)))
  (let [labels (create-labels)]
    [[:script {:src "/xxx.chart.js"}]
     [:h4 "last seven days "
        [:small (string " (" (sum data) ")")]]
     [:canvas {:id "chart"}]
     (create-chart data labels)]))

