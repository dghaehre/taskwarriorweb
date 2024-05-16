(use sh)

(defn push [item]
  (let [desc    (item :description)
        project (item :project)
        topic   (dyn :notify-topic)
        header (cond
                 (string? project) (string "Title: " project)
                 "Title: Inbox")]
    (assert (string? desc))
    (assert (string? topic))
    ($ curl -X POST -d ,desc --header ,header ,(string "https://ntfy.sh/" topic))))

(comment
  (do
    (setdyn :notify-topic "test")
    (push {:description "test"})))
