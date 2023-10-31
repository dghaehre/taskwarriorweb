(use joy)
(use judge)
(use time)

(defn htmx-redirect [path & otherstuff]
  "Adds a HX-Redirect header for it to work with client side redirect (htmx)"
  (let [location  (url-for path ;otherstuff)]
    @{:status 200
      :body " "
      :headers @{"Location" location
                 "HX-Redirect" location}}))

(defn url-redirect [path]
  @{:status 302
    :body " "
    :headers @{"Location" path}})

(defmacro protect-error-page [body]
  ~(let [[success v] (protect ,body)]
    (if success v
      (htmx-redirect :error-page {:? {:reason v}}))))

(defn is-project? [item name]
  (let [project (get item :project)]
    (string/has-prefix? name project)))

(defn exist? [x]
 (and (not (nil? x)) (not (= "" x))))

(defn with-zero [n]
  (assert (number? n))
  (if (< 9 n)
    (string n)
    (string "0" n)))

(test (with-zero 1) "01")
(test (with-zero 10) "10")
(test (with-zero 0) "00")

# TODO: add tomorrow, yestaerday etc.
(defn display-time [t]
  (default t "")
  (if (= t "") ""
    (let [{:month-day d
           :month m
           :year y
           :minutes minutes
           :hours hours} (os/date (time/parse "%Y%m%dT%H%M%S%z" t "UTC") :local)]
      (string (string (with-zero (+ 1 d)) "/" (with-zero (+ 1 m)) "/" y)
              (if (and (= hours 0) (= minutes 0)) ""
                (string " " (with-zero hours) ":" (with-zero minutes)))))))

(test (display-time "20230913T174428Z") "13/09/2023 19:44")
(test (time/parse "%Y%m%dT%H%M%S%z" "20230913T174428Z") 1694619868)
(test (display-time "") "")

(defn get-root-projects [items]
  (var projects @{})
  (each i items
    (let [root (as->  (get i :project "") _
                      (string/split "." _)
                      (get _ 0))]
     (put projects root true)))
  (keys projects))

(test (get-root-projects [{:project "a.b.c"} {:project "a.b.d"} {:project "hei.sdf"}]) @["a" "hei"])
(test (get-root-projects []) @[])
