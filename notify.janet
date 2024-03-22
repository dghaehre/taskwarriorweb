(use jurl)

(defn push [item]
  (let [desc    (item :description)
        project (item :project)
        topic   (dyn :notify-topic)]
    (assert (string? desc))
    (assert (string? project))
    (assert (string? topic))
    (def req (->> (string "https://ntfy.sh/" topic)
                  (http :post)
                  (body desc)
                  (headers {:Title project})))
    (req)))

(comment
  (push {:description "test" :project "test"}))
