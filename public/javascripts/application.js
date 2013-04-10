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
      s = " since " + d.getFullYear() + "-" + fd(d.getMonth() + 1) + "-" + fd(d.getDate()) + " " +
          fd(d.getHours()) + ":" + fd(d.getMinutes()) + ":" + fd(d.getSeconds());
    }
  }
  return s;
};


escape_html = function(str)
{
    return str
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
}


update_status = function(box, thing)
{
  var stat = box.find('.status').first();
  var href;
  if (thing.bucket_state_counts) {
    href = "/project/show_build/" + thing.id;
  } else {
    href = "/project/show_bucket/" + thing.id;
  }
  if (stat.length == 0) {
    stat = $("<span class='status'></span>").appendTo(box);
  }
  stat.empty();
  var s = "<a href='" + href + "' target='_blank'>" +
      "<span class='" + status_css_class(thing.status) + "'>" + status_message(thing.status);
  if (thing.bucket_state_counts) {
    s += " (";
    var prepend_comma = false;
    _.each(thing.bucket_state_counts, function(value, key) {
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
  s += duration(thing) + "</a></span>";
  $(s).appendTo(stat);
};


render_title_span = function(box, title, details, click)
{
  return $("<span title='" + escape_html(details) + "' class='link'>" + escape_html(title) + "</span>").
      appendTo(box).click(click);
};


render_log = function(pre, log)
{
  pre.append(escape_html(log));
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
    var log_id = "log_" + bucket.id;
    var overlay_id = "overlay_" + log_id;

    $("<div class='overlay' id='" + overlay_id + "'>" +
      "<pre class='log' id='" + log_id + "'></pre>"
    + "</div>").appendTo($('#container'));

    var box = $("<div class='box' id='" + bucket.id + "'></div>").appendTo(build_box);
    render_title_span(box, bucket.name, "auf " + bucket.worker_uri,
      function() {
        update_log(bucket.id);
      }
    ).attr('rel', "#" + overlay_id).overlay();
    update_status(box, bucket);
  }
};


render_build = function(div, build, css_class, insert_before)
{
  var build_box = $('#' + build.id);
  update = build_box.length > 0;
  if (update) {
    update_status(build_box, build);
  } else {
    build_box = $("<div class='box " + css_class + "' id='" + build.id + "'></div>");
    if (insert_before) {
      build_box.insertBefore(insert_before);
    } else {
      build_box.appendTo(div);
    }
    title_box = $("<div class='title'>").appendTo(build_box);
    bucket_box = $("<div class='box buckets'>").appendTo(build_box).hide();
    render_title_span(title_box, build.short_identifier,
      build.identifier + " verwaltet von " + build.leader_uri,
      function() {
        build_box.find('.buckets').toggle();
      }
    );
    update_status(title_box, build);
    if (build.gitweb_url) {
      $("<a href='" + build.gitweb_url +
          "' class='button' target='_blank'>Commit anschauen</a>").appendTo(title_box);
    }
  }
  _.each(_.sortBy(build.in_work_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(bucket_box, bucket, update);
  });
  _.each(_.sortBy(build.failed_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(bucket_box, bucket, update);
  });
  _.each(_.sortBy(build.pending_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(bucket_box, bucket, update);
  });
};

render_builds = function(div, project, update)
{
  var last_build = project.last_build;
  if (last_build) {
    var last_build_box = div.find('.last_build');
    if (update && last_build.id != last_build_box.attr('id')) {
      div.empty();
      update = false;
    }
    render_build(div, last_build, 'last_build');
    if (update) {
      _.each(last_build.done_buckets, function(bucket) { $('#' + bucket.id).remove(); });
    } else if (project.previous_build_id) {
      $("<span class='link' id='" + project.previous_build_id +
          "'>mehr anzeigen</span>").appendTo(div).click(function() {
        var show_more = $(this);
        $.ajax({
          url: '/project/old_build/' + show_more.attr('id'),
          dataType: 'json',
          success: function(result) {
            if (result.previous_build_id) {
              show_more.attr('id', result.previous_build_id);
            } else {
              show_more.remove();
              show_more = null;
            }
            render_build(div, result.build, '', show_more);
          },
          error: function(result) {
            alert("Build holen fehlgeschlagen." + result.response);
          }
        });
      });
    }
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
          build_button.removeClass('disabled');
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
          update_status(title, build);
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

        var system_error = $("#" + project.id + "_error");
        if (project.last_system_error) {
          if (system_error.length == 0) {
            system_error = $("<pre id='" + project.id + "_error'></pre>").appendTo(box);
            render_log(system_error, project.last_system_error);
          }
        } else {
          system_error.remove();
        }

        var builds_box = box.find('.builds');
        if (builds_box.length == 0) {
          builds_box = $("<div class='builds'></div>").appendTo(box).hide();
        }
        render_builds(builds_box, project, update);
      });
      update_search();
    },
    error: function(result) {
      //$('#spinner').fadeOut(100);
      alert("Projekte holen fehlgeschlagen." + result.response);
    }
  });
};

var init_search = function() {
  $('#search').val(('' + window.location.hash).replace(/#/, ''));
  update_search();
}

var update_search = function() {
  var text = $('#search').val();
  window.location.hash = text;
  $('.box').show();
  if (text !== '') {
    $('.box:not(:contains("' + text + '"))').hide();
  }
}

$(document).ready(function() {
  init_search();
  update_projects();
  setInterval("update_projects();", 10000);
});
