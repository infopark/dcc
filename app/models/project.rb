# FIXME: In Project noch zu implementieren
#    -> should_be_build = build_requested || current_commit != last_commit
#    -> commit_no passend erzeugen (nil, 2, 3, 4...) -> nach vorhandenen buckets schauen
#    -> last_commit in der DB auf current_commit setzen
#    -> build_requested in der DB auf false setzen
#    -> buckets in der DB erzeugen
class Project < ActiveRecord::Base
end
