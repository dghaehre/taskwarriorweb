(use sh)

(defn push [item]
  (let [desc    (item :description)
        project (item :project)
        topic   (dyn :notify-topic)
        header (string "Title: " project)]
    (assert (string? desc))
    (assert (string? project))
    (assert (string? topic))
    ($ curl -X POST -d ,desc --header ,header ,(string "https://ntfy.sh/" topic))))

(comment
  (push {:description "test" :project "test"}))
