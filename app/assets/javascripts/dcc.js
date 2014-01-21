/*!
 *
 * DCC Client
 */

window.onbeforeunload = function() { show_error = function() {}; };

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


_provide_element = function(identifier, container, prepend, default_content, create_callback) {
  var element = $(container).find(identifier).first();
  if (element.length == 0) {
    if (prepend) {
      element = $(default_content).prependTo($(container));
    } else {
      element = $(default_content).appendTo($(container));
    }
    if (identifier[0] == "#") {
      element.attr("id", identifier.substring(1));
    } else if (identifier[0] == '.') {
      var clazz = identifier.substring(1);
      if (!element.hasClass(clazz)) {
        element.addClass(clazz);
      }
    }
    if (create_callback) { create_callback(element); }
  }
  return element;
};


provide_element = function(identifier, container, default_content, create_callback) {
  return _provide_element(identifier, container, false, default_content, create_callback);
};


provide_first_element = function(identifier, container, default_content, create_callback) {
  return _provide_element(identifier, container, true, default_content, create_callback);
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
  provide_element('.close', messages, "<div></div>",
      function(button) { button.click(function() {
        messages.empty();
        overlay.hide();
        _.each(error_actions, function(action) { action(); });
        error_actions = [];
      }); });
  overlay.show();
};


render_title = function(box, title, title_css_class, details, show_details, thing, click,
    title_span_create_callback)
{
  var title_box = provide_element(".title", box, "<div></div>");
  var title_span = provide_element(".title", title_box, "<span class='link'>" + escape_html(title) +
      "</span>", function(element) {
        element.click(click);
        if (title_span_create_callback) {
          title_span_create_callback(element);
        }
      });
  if (title_css_class) {
    title_span.addClass(title_css_class);
  }
  if (show_details) {
    var details_span = provide_element(".details", title_box, "<span/>");
    details_span.empty();
    details_span.append(escape_html(details));
  } else {
    title_span.attr("title", details);
  }

  var stat = provide_element('.status', title_box, "<span></span>");
  stat.empty();
  if (thing) {
    var href;
    if (thing.bucket_state_counts) {
      href = "/project/show_build/" + thing.id;
    } else {
      href = "/project/show_bucket/" + thing.id;
    }
    var stat_link = provide_element('.link', stat, "<a href='" + href + "' target='_blank'></a>");
    stat_link.empty();

    var s = "<span class='" + status_css_class(thing.status) + "'>" + status_message(thing.status);
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
    s += duration(thing);
    s += "</span>"
    $(s).appendTo(stat_link);
  }

  return title_box;
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


project_id_from_element = function(e)
{
  return e.length == 0 ? null : id_from_element('project', e);
};


overlay = function(click_element, overlay_element)
{
    provide_element('.close', overlay_element, "<div></div>",
        function(element) { element.click(function() { overlay_element.toggle(); }); });
    click_element.click(function() { overlay_element.toggle(); });
};


render_bucket = function(build_box, bucket)
{
  var bucket_box_id = bucket_html_id(bucket.id);
  var bucket_box = provide_element("#" + bucket_box_id, build_box, "<div class='box'></div>");

  var log_id = bucket_html_id(bucket.id, 'log');
  var overlay_id = "overlay_" + log_id;
  var log_overlay = provide_element("#" + overlay_id, "#container",
      "<div class='overlay'><div class='container'>" +
        "<pre class='log' id='" + log_id + "'></pre>" +
      "</div></div>");

  render_title(bucket_box, bucket.name, null, "auf " + bucket.worker_hostname, false, bucket,
      function() { update_log(bucket.id); },
      function(title_span) { overlay(title_span, log_overlay); });
};


render_build = function(div, build, css_class)
{
  var build_box_id = build_html_id(build.id);
  var build_box = provide_element("#" + build_box_id, div, "<div class='box " + css_class + "'/>");

  var title_box = render_title(build_box, build.short_identifier, null,
      build.identifier + " verwaltet von " + build.leader_hostname, false, build,
      function() { build_box.find('.buckets').toggle(); });
  if (build.gitweb_url) {
    provide_element(".vcslink", title_box,
        "<a href='" + build.gitweb_url + "' class='button' target='_blank'>Commit anschauen</a>");
  }

  var bucket_box = provide_element(".buckets", build_box, "<div class='box'/>", function(box) {
    box.hide();
  });
  _.each(_.sortBy(build.in_work_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(bucket_box, bucket);
  });
  _.each(_.sortBy(build.failed_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(bucket_box, bucket);
  });
  _.each(_.sortBy(build.pending_buckets, function(b) { return b.name; }), function(bucket) {
    render_bucket(bucket_box, bucket);
  });
  _.each(build.done_buckets, function(bucket) { find_bucket_element(bucket.id).remove(); });
};

render_builds = function(container, project)
{
  var builds_box = provide_element('.builds', container, "<div></div>",
      function(element) { element.hide(); });
  var last_build = project.last_build;
  if (last_build) {
    var previous_last_build_id = build_id_from_element(builds_box.find('.last_build'));

    if (last_build.id != previous_last_build_id) {
      builds_box.empty();
    }

    var builds_container = provide_element('.container', builds_box, "<span></span>");
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


perform_project_action = function(project, action, error_message, success_handler)
{
  var post_params = {};
  post_params[$('meta[name=csrf-param]').attr('content')] =
      $('meta[name=csrf-token]').attr('content');

  $.ajax({
    url: '/project/' + action + '/' + project.id,
    type: 'POST',
    data: post_params,
    dataType: 'json',
    success: success_handler,
    error: function(request, message, exception) {
      show_error(error_message, message);
    }
  });
};


current_user = function() {
  return $("#user").attr('data-login');
};


render_project = function(project) {
  var project_box = provide_element("#" + project_html_id(project.id), this, "<div class='box'/>");
  var details = "URL: " + project.url + "; Branch: " + project.branch;
  var title_css_class = 'public';
  if (project.owner) {
    if (project.owner == current_user()) {
      title_css_class = 'my';
    } else {
      title_css_class = 'other';
      details += "; Owner: " + project.owner;
    }
  }
  var title_box = render_title(project_box, project.name, title_css_class, details, true,
      project.last_build, function() { project_box.find('.builds').toggle(); });

  var buttons = provide_element(".buttons", title_box, "<div/>", function(element) {
    $("<div class='button red'>Löschen</div>").appendTo(element).click(function() {
      if (confirm("Soll das Projekt „" + project.name + "“ wirklich gelöscht werden?")) {
        perform_project_action(project, 'delete', "Löschen fehlgeschlagen",
            function(result) { project_box.remove(); });
      }
    });
  });
  var build_button = provide_element(".build", buttons, "<div class='button green'>Bauen</div>");
  var stats_button = provide_element(".stats", buttons,
      "<a title='Stats' class='button yellow'>◔</a>");
  stats_button.click(function() { show_stats(project.id); });
  overlay(stats_button, $('#overlay'));

  if (project.build_requested) {
    build_button.addClass('disabled');
  } else {
    build_button.removeClass('disabled');
    build_button.unbind('click');
    build_button.click(function() {
      perform_project_action(project, 'build', "Trigger Build fehlgeschlagen",
          function(result) {
            build_button.unbind('click');
            build_button.addClass("disabled");
          });
    });
  }

  var build = project.last_build;
  if (build) {
    var span = provide_element('.indicator', title_box, "<span></span>");
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
      system_error = $("<pre id='" + project_html_id(project.id, 'error') +
          "'></pre>").appendTo(project_box);
      render_log(system_error, project.last_system_error);
    }
  } else {
    system_error.remove();
  }

  render_builds(project_box, project);
};


var show_all_projects = false;
var render_projects = function(projects) {
  provide_first_element("#show_all_projects", "#mainContent",
      "<div><label>alle anzeigen</label></div>", function(div) {
        provide_first_element("input", div, "<input type='checkbox'/>", function(checkbox) {
          checkbox.change(function() {
            show_all_projects = checkbox.prop('checked');
            update_projects();
          });
        });
      });
  var projects_element = provide_element("#projects", "#mainContent", "<div></div>");

  if (!show_all_projects) {
    projects = _.filter(projects, function(p) {
      return p.owner == null || p.owner == current_user();
    });
  }
  _.each($("#projects > div"), function(project_element) {
    project_element = $(project_element);
    var id = project_id_from_element(project_element);
    if (!_.find(projects, function(p) { return p.id == id; })) {
      project_element.remove();
    }
  });
  _.each(_.sortBy(projects, function(p) { return p.name; }), render_project, projects_element);
};


var update_projects_timeout = null;
var schedule_update_projects = function() {
  if (update_projects_timeout) {
    clearTimeout(update_projects_timeout);
  }
  update_projects_timeout = setTimeout("update_projects();", 10000);
};


var update_projects = function() {
  $('#spinner').fadeIn(300);
  $.ajax({
    url: '/project/list',
    dataType: 'json',
    success: function(result) {
      $('#spinner').fadeOut(500);
      render_projects(result.projects);
      update_search(true);
      schedule_update_projects();
    },
    error: function(request, message, exception) {
      $('#spinner').fadeOut(100);
      show_error("Projekte holen fehlgeschlagen", message, function() {
        schedule_update_projects();
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

render_gui = function() {
  init_search();
  update_search();
  update_projects();
};
