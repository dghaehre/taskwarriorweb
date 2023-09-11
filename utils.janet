(use joy)

(defn htmx-redirect [path & otherstuff]
  "Adds a HX-Redirect header for it to work with client side redirect (htmx)"
  (let [location  (url-for path ;otherstuff)]
    @{:status 200
      :body " "
      :headers @{"Location" location
                 "HX-Redirect" location}}))

(defmacro protect-error-page [body]
  ~(let [[success v] (protect ,body)]
    (if success v
      (htmx-redirect :error-page {:? {:reason v}}))))

(defn exist? [x]
 (and (not (nil? x)) (not (= "" x))))
