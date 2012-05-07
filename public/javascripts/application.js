status_message = function(status)
{
  switch(status) {
    case 10:
      return 'done';
    case 20:
      return 'pending';
    case 30:
      return 'in work';
    case 35:
      return 'processing failed';
    case 40:
      return 'failed';
    default:
      return 'unknown status ' + status;
  }
};


status_css_class = function(status)
{
  if (status <= 10) {
    return 'success';
  } else if (status <= 30) {
    return 'in_progress';
  } else {
    return 'failure';
  }
};


unfinished_buckets_count = function(build)
{
  return build.bucket_state_counts["30"] + build.bucket_state_counts["20"];
};


buckets_in_work_count = function(build)
{
  return build.bucket_state_counts["30"];
};


format_duration = function(interval)
{
  interval /= 1000;
  var seconds = interval % 60;
  interval -= seconds;
  var minutes = interval / 60 % 60;
  interval -= minutes * 60;
  var hours = interval / 3600;
  var parts = [];
  if (hours > 0) {
    parts.push("" + hours + " hour" + (hours > 1 ? "s" : ""));
  }
  if (minutes > 0) {
    parts.push("" + minutes + " minute" + (minutes > 1 ? "s" : ""));
  }
  if (seconds > 0) {
    parts.push("" + seconds + " second" + (seconds > 1 ? "s" : ""));
  }
  return parts.join(" ");
};


fd = function(num)
{
  return (num < 10 ? "0" : "") + num;
};


duration = function(build)
{
  s = ""
  if (build.started_at) {
    if (build.finished_at) {
      s = " in " + format_duration(Date.parse(build.finished_at) - Date.parse(build.started_at));
    } else {
      var d = new Date(Date.parse(build.started_at));
      s = " since " + d.getFullYear() + "-" + fd(d.getMonth()) + "-" + fd(d.getDay()) + " " +
          fd(d.getHours()) + ":" + fd(d.getMinutes()) + ":" + fd(d.getSeconds());
    }
  }
  return s;
};


update_status = function(box, thing, sub_things)
{
  var span = box.find('.status');
  if (span.length == 0) {
    span = $("<span class='status'></span>").appendTo(box);
  }
  span.empty();
  var s = "<span class='" + status_css_class(thing.status) + "'>"
      + status_message(thing.status);
  if (sub_things) {
    s += " (";
    var prepend_comma = false;
    _.each(sub_things, function(value, key) {
      if (value > 0) {
        if (prepend_comma) {
          s += ", ";
        }
        s += value + " " + status_message(parseInt(key));
        prepend_comma = true;
      }
    });
    s += ")";
  }
  s += duration(thing) + "</span>";
  $(s).appendTo(span);
};


render_title_span = function(box, title, details, click)
{
  $("<span title='" + details + "' class='link'>" + title + "</span>").appendTo(box).click(click);
};


render_log = function(pre, log)
{
  log = log.replace(/</g, '&lt;').replace(/>/g, '&gt;');
  pre.append(log);
};


update_log = function(bucket_id)
{
  var pre = $("#log_" + bucket_id);
  $.ajax({
    url: '/project/log/' + bucket_id,
    dataType: 'json',
    success: function(result) {
      pre.empty();
      if (result.log) {
        // FIXME pre-Klasse ändern
        render_log(pre, result.log);
      } else {
        // FIXME pre-Klasse ändern
        _.each(result.logs, function(log) {
          render_log(pre, log);
        });
        // FIXME nicht einschalten, wenn invisible
        // FIXME oder gar nicht mit eigener aktualisierung sondern nur, immer wenn render builds
        // (und visible)
        setTimeout("update_log('" + bucket_id + "');", 5000);
      }
    },
    error: function(result) {
      alert("Log holen fehlgeschlagen." + result.response);
    }
  });
  return pre;
};


render_bucket = function(build_box, bucket, update)
{
  if (update) {
    update_status($("#" + bucket.id), bucket);
  } else {
    var box = $("<div class='box' id='" + bucket.id + "'></div>").appendTo(build_box);
    var title_span = render_title_span(box, bucket.name, "auf " + bucket.worker_uri,
      function() {
        update_log(bucket.id).toggle();
      }
    );
    update_status(box, bucket);
    $("<pre class='log' id='log_" + bucket.id + "'></pre>").appendTo(box).hide();
  }
};


render_builds = function(div, project, update)
{
  var last_build = project.last_build;
  var build_box = div.find('.box');
  if (!update || last_build.id != div.find('.last_build').attr('id')) {
    div.empty();
    build_box = $("<div class='box last_build' id='" + last_build.id + "'></div>").appendTo(div);
    $(
      "<span class='link' title='" + last_build.identifier +
          " verwaltet von " + last_build.leader_uri + "'>" +
        last_build.short_identifier +
      "</span>"
    ).appendTo(build_box);
    if (last_build.gitweb_url) {
      $("<a href='" + last_build.gitweb_url +
          "' class='button' target='_blank'>Commit anschauen</a>").appendTo(build_box);
    }
    $("<a href='/project/show_build/" + last_build.id +
        "' class='button' target='_blank'>statische Build-Seite</a>").appendTo(build_box);
    update = false;
  }
  _.each(_.sortBy(last_build.in_work_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(build_box, bucket, update);
  });
  _.each(_.sortBy(last_build.failed_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(build_box, bucket, update);
  });
  _.each(_.sortBy(last_build.pending_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(build_box, bucket, update);
  });
  if (update) {
    _.each(last_build.done_buckets, function(bucket) { $('#' + bucket.id).remove(); });
  }
};


update_projects = function() {
  //$('#spinner').fadeIn(300);
  $.ajax({
    url: '/project/list',
    dataType: 'json',
    success: function(result) {
      //$('#spinner').fadeOut(500);
      var projects = $("#projects");
      if (projects.length == 0) {
        projects = $("<div id='projects'></div>").appendTo("#mainContent");
      }
      _.each(_.sortBy(result.projects, function(p) { return p.name; }), function(project) {
        var box = $("#" + project.id);
        var update = true;
        var build_button;
        var title;
        if (box.length > 0) {
          build_button = box.find('.buttons').find('.build');
          title = box.find('.title');
        } else {
          box = $("<div class='box' id='" + project.id + "'></div>").appendTo(projects);
          title = $("<div class='title'></div>)").appendTo(box);
          var buttons = $("<div class='buttons'></div>").appendTo(title);
          $("<div class='button red'>Löschen</div>").appendTo(buttons).click(function() {
            if (confirm("Soll das Projekt „" + project.name + "“ wirklich gelöscht werden?")) {
              $.ajax({
                url: '/project/delete/' + project.id,
                dataType: 'json',
                success: function(result) {
                  box.remove();
                },
                error: function(result) {
                  alert("Löschen fehlgeschlagen: " + result);
                }
              });
            }
          });
          build_button = $("<div class='button green build'>Bauen</div>").appendTo(buttons);
          update = false;
        }
        if (project.build_requested) {
          build_button.addClass('disabled');
        } else {
          build_button.click(function() {
            $.ajax({
              url: '/project/build/' + project.id,
              dataType: 'json',
              success: function(result) {
                build_button.unbind('click');
                build_button.addClass("disabled");
              },
              error: function(result) {
                alert("Trigger Build fehlgeschlagen: " + result);
              }
            });
          });
        };
        var build = project.last_build;
        if (!update) {
          render_title_span(title, project.name, "URL: " + project.url + "; " + project.branch,
            function() {
              box.find('.builds').toggle();
            }
          );
        }
        if (build) {
          update_status(title, build, build.bucket_state_counts);
          var span = title.find('.indicator');
          if (span.length == 0) {
            span = $("<span class='indicator'></span>").appendTo(title);
          }
          span.empty();
          if (unfinished_buckets_count(build) > 0) {
            $("<span class='progress_indicator'>" +
              fd(buckets_in_work_count(build)) +
            "</span>").appendTo(span);
          }
        }
        var builds_box = box.find('.builds');
        if (builds_box.length == 0) {
          builds_box = $("<div class='builds'></div>").appendTo(box).hide();
        }
        render_builds(builds_box, project, update);
      });
    },
    error: function(result) {
      //$('#spinner').fadeOut(100);
      alert("Projekte holen fehlgeschlagen." + result.response);
    }
  });
};


$(document).ready(function() {
  update_projects();
  setInterval("update_projects();", 10000);
});
