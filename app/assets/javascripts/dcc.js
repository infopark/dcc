/*!
 *
 * DCC Client
 */

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
};


// FIXME Logik, die aus identifier automatisch Klasse oder ID bestimmt und dem erzeugten Element
// setzt → kein händisches reinrühren in den Aufrufern mehr
provide_element = function(identifier, container, default_content, create_callback) {
  var element = $(container).find(identifier).first();
  if (element.length == 0) {
    element = $(default_content).appendTo($(container));
    if (create_callback) { create_callback(element); }
  }
  return element;
};


error_actions = [];
show_error = function(headline, message, ok_action) {
  if (ok_action) { error_actions.push(ok_action); }
  var overlay = $("#error_overlay");
  var messages = $("#error_messages");
  messages.append(escape_html(headline));
  messages.append(": ");
  messages.append(escape_html(message));
  messages.append("<br/>");
  provide_element('.close', messages, "<div class='close'></div>",
      function(button) { button.click(function() {
        messages.empty();
        overlay.hide();
        _.each(error_actions, function(action) { action(); });
        error_actions = [];
      }); });
  overlay.show();
};


// FIXME das muss auch den title-span von Buckets aktualisieren (da kommt der hostname dazu…)
update_status = function(box, thing)
{
  var stat = provide_element('.status', box, "<span class='status'></span>");
  var href;
  if (thing.bucket_state_counts) {
    href = "/project/show_build/" + thing.id;
  } else {
    href = "/project/show_bucket/" + thing.id;
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
  return $("<span title='" + escape_html(details) + "' class='title link'>" + escape_html(title) +
      "</span>").appendTo(box).click(click);
};


render_log = function(pre, log)
{
  pre.append(escape_html(log));
};


update_log = function(bucket_id)
{
  var pre = find_bucket_element(bucket_id, 'log');
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
    error: function(request, message, exception) {
      show_error("Log holen fehlgeschlagen", message, function() {
        setTimeout("update_log('" + bucket_id + "');", 5000);
      });
    }
  });
  return pre;
};


html_id = function(clazz, id, specifier)
{
  var suffix = "";
  if (specifier) {
    suffix = "_" + specifier;
  }
  return clazz + "_" + id + suffix;
};


bucket_html_id = function(id, specifier)
{
  return html_id('bucket', id, specifier);
};


build_html_id = function(id, specifier)
{
  return html_id('build', id, specifier);
};


project_html_id = function(id, specifier)
{
  return html_id('project', id, specifier);
};


find_bucket_element = function(id, specifier)
{
  return $("#" + bucket_html_id(id, specifier));
};


find_project_element = function(id, specifier)
{
  return $("#" + project_html_id(id, specifier));
};


id_from_element = function(clazz, e)
{
  var components = e.attr('id').split('_');
  if (components[0] == clazz) {
    return components[1];
  }
};


build_id_from_element = function(e)
{
  return e.length == 0 ? null : id_from_element('build', e);
};


overlay = function(click_element, overlay_element)
{
    provide_element('.close', overlay_element, "<div class='close'></div>",
        function(element) { element.click(function() { overlay_element.toggle(); }); });
    click_element.click(function() { overlay_element.toggle(); });
};


render_bucket = function(build_box, bucket)
{
  var bucket_box_id = bucket_html_id(bucket.id);
  var bucket_box = provide_element("#" + bucket_box_id, build_box,
      "<div class='box' id='" + bucket_box_id + "'></div>", function(box) {
        var log_id = bucket_html_id(bucket.id, 'log');
        var overlay_id = "overlay_" + log_id;

        var log_overlay = $("<div class='overlay' id='" + overlay_id + "'><div class='container'>" +
              "<pre class='log' id='" + log_id + "'></pre>" +
            "</div></div>").appendTo($('#container'));

        overlay(render_title_span(box, bucket.name, "auf " + bucket.worker_hostname, function() {
              update_log(bucket.id);
            }), log_overlay);
      });
  update_status(bucket_box, bucket);
};


render_build = function(div, build, css_class)
{
  var build_box_id = build_html_id(build.id);
  var build_box = provide_element("#" + build_box_id, div,
      "<div class='box " + css_class + "' id='" + build_box_id + "'></div>", function(box) {
        var title_box = $("<div class='title'>").appendTo(box);
        var bucket_box = $("<div class='box buckets'>").appendTo(box).hide();
        render_title_span(title_box, build.short_identifier,
          build.identifier + " verwaltet von " + build.leader_hostname,
          function() { box.find('.buckets').toggle(); }
        );
        update_status(title_box, build);
        if (build.gitweb_url) {
          $("<a href='" + build.gitweb_url +
              "' class='button' target='_blank'>Commit anschauen</a>").appendTo(title_box);
        }
        _.each(_.sortBy(build.in_work_buckets, function(b) { return b.name; }), function(bucket) {
          render_bucket(bucket_box, bucket);
        });
        _.each(_.sortBy(build.failed_buckets, function(b) { return b.name; }), function(bucket) {
          render_bucket(bucket_box, bucket);
        });
        _.each(_.sortBy(build.pending_buckets, function(b) { return b.name; }), function(bucket) {
          render_bucket(bucket_box, bucket);
        });
      });
  update_status(build_box, build);
  _.each(build.done_buckets, function(bucket) { find_bucket_element(bucket.id).remove(); });
};

render_builds = function(container, project)
{
  var builds_box = provide_element('.builds', container, "<div class='builds'></div>",
      function(element) { element.hide(); });
  var last_build = project.last_build;
  if (last_build) {
    var builds_container = provide_element('.container', builds_box,
        "<span class='container'></span>");
    var previous_last_build_id = build_id_from_element(builds_container.find('.last_build'));

    if (last_build.id != previous_last_build_id) {
      builds_container.empty();
    }

    render_build(builds_container, last_build, 'last_build');

    if (last_build.id != previous_last_build_id && project.previous_build_id) {
      $("<span class='link' id='" + build_html_id(project.previous_build_id) +
          "'>mehr anzeigen</span>").appendTo(builds_box).click(function() {
        var show_more = $(this);
        $.ajax({
          url: '/project/old_build/' + build_id_from_element(show_more),
          dataType: 'json',
          success: function(result) {
            if (result.previous_build_id) {
              show_more.attr('id', build_html_id(result.previous_build_id));
            } else {
              show_more.remove();
              show_more = null;
            }
            render_build(builds_container, result.build, '');
          },
          error: function(request, message, exception) {
            show_error("Build holen fehlgeschlagen", message);
          }
        });
      });
    }
  }
};


render_project = function(project) {
  var box = find_project_element(project.id);
  var build_button;
  var title;
  if (box.length > 0) {
    build_button = box.find('.buttons').find('.build');
    title = box.find('.title');
  } else {
    box = $("<div class='box' id='" + project_html_id(project.id) +
        "'></div>").appendTo(this);
    title = $("<div class='title'></div>)").appendTo(box);
    var buttons = $("<div class='buttons'></div>").appendTo(title);
    $("<div class='button red'>Löschen</div>").appendTo(buttons).click(function() {
      if (confirm("Soll das Projekt „" + project.name + "“ wirklich gelöscht werden?")) {
        $.ajax({
          url: '/project/delete/' + project.id,
          type: 'POST',
          dataType: 'json',
          success: function(result) {
            box.remove();
          },
          error: function(request, message, exception) {
            show_error("Löschen fehlgeschlagen", message);
          }
        });
      }
    });
    build_button = $("<div class='button green build'>Bauen</div>").appendTo(buttons);
    overlay($("<a title='Stats' class='button yellow stats' onclick='show_stats(" +
        project.id + ")'>◔</a>").appendTo(buttons), $('#overlay'));
    render_title_span(title, project.name, "URL: " + project.url + "; " + project.branch,
        function() { box.find('.builds').toggle(); });
  }

  if (project.build_requested) {
    build_button.addClass('disabled');
  } else {
    build_button.removeClass('disabled');
    build_button.unbind('click');
    build_button.click(function() {
      $.ajax({
        url: '/project/build/' + project.id,
        type: 'POST',
        dataType: 'json',
        success: function(result) {
          build_button.unbind('click');
          build_button.addClass("disabled");
        },
        error: function(request, message, exception) {
          show_error("Trigger Build fehlgeschlagen", message);
        }
      });
    });
  }

  var build = project.last_build;
  if (build) {
    update_status(title, build);
    var span = provide_element('.indicator', title, "<span class='indicator'></span>");
    span.empty();
    if (unfinished_buckets_count(build) > 0) {
      $("<span class='progress_indicator'>" +
        fd(buckets_in_work_count(build)) +
      "</span>").appendTo(span);
    }
  }

  var system_error = find_project_element(project.id, 'error');
  if (project.last_system_error) {
    if (system_error.length == 0) {
      system_error =
          $("<pre id='" + project_html_id(project.id, 'error') + "'></pre>").appendTo(box);
      render_log(system_error, project.last_system_error);
    }
  } else {
    system_error.remove();
  }

  render_builds(box, project);
};


render_projects = function(projects) {
  var projects_element = provide_element("#projects", "#mainContent", "<div id='projects'></div>");
  _.each(_.sortBy(projects, function(p) { return p.name; }), render_project, projects_element);
};


update_projects = function() {
  $('#spinner').fadeIn(300);
  $.ajax({
    url: '/project/list',
    dataType: 'json',
    success: function(result) {
      $('#spinner').fadeOut(500);
      render_projects(result.projects);
      update_search(true);
      setTimeout("update_projects();", 10000);
    },
    error: function(request, message, exception) {
      $('#spinner').fadeOut(100);
      show_error("Projekte holen fehlgeschlagen", message, function() {
        setTimeout("update_projects();", 10000);
      });
    }
  });
};

var init_search = function() {
  $('#search').val(('' + window.location.hash).replace(/#/, ''));
};

var update_search = function(prefer_hash) {
  var text = $('#search').val();
  var hash = ('' + window.location.hash).replace(/#/, '');
  if (text != hash) {
    if (prefer_hash) {
      text = hash;
      init_search();
    }
    window.location.hash = text;
  }
  $('#projects > .box').show();
  if (text !== '') {
    $('#projects > .box:not(:contains("' + text + '"))').hide();
  }
};

var show_stats = function(project_id) {
  $('#overlay .details').empty();
  $.getJSON("/stats/project/" + project_id, function(json) {
    var data = new google.visualization.DataTable();
    data.addColumn('string', 'Date');
    data.addColumn('number', 'Slowest');
    data.addColumn('number', 'Fastest');
    data.addRows(json.rows);
    var vAxis = {
      format: '# min',
      gridlines: { color: '#dfdaad', count: json.max / 5 },
      minorGridlines: { count: 5 },
      viewWindow: { max: json.max / 5 * 5, min: 0 }
    };
    new google.visualization.ColumnChart($('#overlay .details').get(0)).draw(data, {
      backgroundColor: '#fffacd',
      bar: { groupWidth: '70%' },
      colors: ['#77c76f', '#27771f'],
      focusTarget: 'category',
      height: '100%',
      isStacked: true,
      legend: { position: 'bottom' },
      series: [ { targetAxisIndex: 0 }, { targetAxisIndex: 1 } ],
      title: json.name + " - Cruise Duration by Green Commit",
      vAxes: [vAxis, vAxis],
      width: '100%'
    });
  });
};

$(document).ready(function() {
  init_search();
  update_search();
  update_projects();
});
