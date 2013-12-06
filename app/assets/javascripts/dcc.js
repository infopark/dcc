/*!
 *
 * DCC Client
 */

window.onbeforeunload = function() { show_error = function() {}; };

var localizer;
var language;
init_localizer = function(data, lang) {
  localizer = data[lang];
  language = lang;
};

status_message = function(status)
{
  switch(status) {
    case 10:
      return localizer.status.done;
    case 20:
      return localizer.status.pending;
    case 30:
      return localizer.status.in_work;
    case 35:
      return localizer.status.processing_failed;
    case 40:
      return localizer.status.failed;
    default:
      return localizer.error.unknown_status + ': ' + status;
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

var status_icon = function(status_code)
{
  switch(status_code) {
    case 10:
      return 'thumbs-up';
    case 20:
      return 'time';
    case 30:
      return 'cog';
    case 35:
      return 'warning-sign';
    case 40:
      return 'thumbs-down';
    default:
      return 'unknown';
  }
};

var append_status = function(element, status_code, value)
{
  if (value != 0) {
    $("<span title='" + status_message(status_code) +
        "' class='" + status_css_class(status_code) + "'>" +
      glyphicon(status_icon(status_code), 'status_icon') +
      (value > 0 ? value : "") +
    "</span>").appendTo(element);
  }
}


var update_panel_status = function(panel, thing)
{
  panel.removeClass("panel-danger panel-info panel-success panel-default");
  if (!thing || !thing.status) {
    panel.addClass("panel-default");
  } else if (thing.status <= 10) {
    panel.addClass("panel-success");
  } else if (thing.status <= 30) {
    panel.addClass("panel-info");
  } else {
    panel.addClass("panel-danger");
  }
  if (thing) {
    var panel_status = provide_first_element('.indicator', panel.find('.panel-heading'),
        "<h2 class='panel-title pull-right'></h2>");
    panel_status.empty();
    if (thing.bucket_state_counts) {
      var build = thing;
      _.each([40, 35, 30, 20, 10], function(status_code) {
        var value = build.bucket_state_counts[status_code.toString()];
        append_status(panel_status, status_code, value);
      });
    } else {
      append_status(panel_status, thing.status);
    }
  }
};


glyphicon = function(name, additional_class) {
  additional_class = additional_class || "prefix_icon"
  return "<i class='glyphicon glyphicon-" + name + " " + additional_class + "'></i>";
};


var icon = function(name) {
  return "<i class='prefix_icon icon icon-" + name + "'></i>";
}


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
  if (str) {
    str = str
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
  }
  return str;
};


_provide_element = function(identifier, container, where, default_content, create_callback) {
  var element = $(container).find(identifier).first();
  if (element.length == 0) {
    if (where == "prepend") {
      element = $(default_content).prependTo($(container));
    } else if (where == "append") {
      element = $(default_content).appendTo($(container));
    } else {
      element = $(default_content).insertBefore(where);
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
  return _provide_element(identifier, container, "append", default_content, create_callback);
};


provide_first_element = function(identifier, container, default_content, create_callback) {
  return _provide_element(identifier, container, "prepend", default_content, create_callback);
};


var error_actions = [];
var error_num = 0;
show_error = function(headline, message, details, ok_action) {
  if (ok_action) { error_actions.push(ok_action); }

  var error_id = "error_" + error_num++;

  $('<div class="panel panel-default">').appendTo($("#error_messages")).append(
    '<div class="panel-heading">' +
      '<h4 class="panel-title">' +
        '<span data-toggle="collapse" data-parent="#error_messages" data-target="#' +
            error_id + '">' +
          escape_html(headline) + ": " + escape_html(message) +
        '</span>' +
      '</h4>' +
    '</div>' +
    '<div id="' + error_id + '" class="panel-collapse collapse">' +
      '<div class="panel-body">' +
        details +
      '</div>' +
    '</div>'
  );

  $("#error_overlay").show();
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
  if (thing) {
    var href;
    if (thing.bucket_state_counts) {
      href = "/project/show_build/" + thing.id;
    } else {
      href = "/project/show_bucket/" + thing.id;
    }
    var stat_link = provide_element('.link', stat, "<a href='" + href + "' target='_blank'></a");
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
        render_log(pre, result.log);
      } else {
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
      show_error(localizer.error.fetch_log_failed, request.statusText, request.responseText,
          function() {
        // FIXME s.o.
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


// FIXME update via event → passend umsortieren! → status in Klasse für sortierung und findung der
// zu aktualisierenden
render_bucket = function(build_box, bucket)
{
  // FIXME
  // - Zusatzinfo (auf Rechner x) mit schickem Icon (Compi) davor rechts im Header
  var bucket_box = provide_element("#bucket_" + bucket.id, build_box,
    '<div class="panel panel-default bucket ' + status_css_class(bucket) +
        '" data-bucket_id="' + bucket.id + '">' +
      '<div class="panel-heading" data-toggle="collapse" data-parent="#' +
          build_box.prop('id') + '" data-target="#log_' + bucket.id + '">' +
        '<h4 class="panel-title">' +
          escape_html(bucket.name) +
        '</h4>' +
      '</div>' +
      '<div id="log_' + bucket.id + '" class="panel-collapse collapse">' +
        '<div class="panel-body">' +
          "<pre id='" + bucket_html_id(bucket.id, "log") + "'>" +
            '<div class="loading"></div>' +
          "</pre>" +
        '</div>' +
      '</div>' +
    '</div>', function(element) {
      element.on('show.bs.collapse', function (evt) {
        update_log(bucket.id);
        element.unbind('show.bs.collapse');
      });
    }
  );
  // FIXME kein update, wenn nicht pending/in_work
  update_panel_status(bucket_box, bucket);
  // FIXME
  // FIXME wollen/brauchen wir noch die html_id-Generatoren?
//  var bucket_box_id = bucket_html_id(bucket.id);
//  var bucket_box = provide_element("#" + bucket_box_id, build_box, "<div class='box'></div>");
//
//  var log_id = bucket_html_id(bucket.id, 'log');
//  var overlay_id = "overlay_" + log_id;
//  var log_overlay = provide_element("#" + overlay_id, "body",
//      "<div class='overlay'><div class='container'>" +
//        "<pre class='log' id='" + log_id + "'></pre>" +
//      "</div></div>");
//
//  render_title(bucket_box, bucket.name, null, "auf " + bucket.worker_hostname, false, bucket,
//      function() { update_log(bucket.id); },
//      function(title_span) { overlay(title_span, log_overlay); });
};


render_build = function(container, build)
{
// FIXME update (nur last_build)
  return provide_element("#build_" + build.id, container,
      "<div class='build panel-group'/>", function(box) {
    box.hide();
    _.each(_.sortBy(build.in_work_buckets, function(b) { return b.name; }), function(bucket) {
      render_bucket(box, bucket);
    });
    _.each(_.sortBy(build.failed_buckets, function(b) { return b.name; }), function(bucket) {
      render_bucket(box, bucket);
    });
    _.each(_.sortBy(build.pending_buckets, function(b) { return b.name; }), function(bucket) {
      render_bucket(box, bucket);
    });
    _.each(_.sortBy(build.done_buckets, function(b) { return b.name; }), function(bucket) {
      render_bucket(box, bucket);
    });
  });

  // FIXME
  // FIXME wollen/brauchen wir noch die html_id-Generatoren?
//  var build_box_id = build_html_id(build.id);
//  var build_box = provide_element("#" + build_box_id, div, "<div class='box " + css_class + "'/>");
//
//  var title_box = render_title(build_box, build.short_identifier, null,
//      build.identifier + " verwaltet von " + build.leader_hostname, false, build,
//      function() { build_box.find('.buckets').toggle(); });
//  if (build.gitweb_url) {
//    provide_element(".vcslink", title_box,
//        "<a href='" + build.gitweb_url + "' class='button' target='_blank'>Commit anschauen</a>");
//  }
//
//  var bucket_box = provide_element(".buckets", build_box, "<div class='box'/>", function(box) {
//    box.hide();
//  });
//  _.each(build.done_buckets, function(bucket) { find_bucket_element(bucket.id).remove(); });
};

var _load_builds = function(last_build_id, pagination, prepend, success_callback) {
  $.ajax({
    url: '/project/previous_builds/' + last_build_id,
    dataType: 'json',
    success: function(result) {
      var loaded_build_ids = pagination.data('loaded_build_ids');
      var builds = pagination.data('builds');
      var new_builds = result.previous_builds;
      if (prepend) {
        new_builds = new_builds.reverse();
        if (!builds[_.last(new_builds).id] && result.continuation_handle) {
          _load_builds(result.continuation_handle, pagination, true, null);
        }
      } else {
        pagination.data('continuation_handle', result.continuation_handle);
      }
      _.each(new_builds, function(build) {
        if (!builds[build.id]) {
          if (prepend) {
            loaded_build_ids.unshift(build.id);
            var offset = pagination.data('offset');
            if (offset > 0) {
              pagination.data('offset', offset + 1)
            }
          } else {
            loaded_build_ids.push(build.id);
          }
          builds[build.id] = build;
        }
      });

      if (success_callback) {
        success_callback();
      }
    },
    error: function(request, message, exception) {
      show_error(localizer.error.fetch_builds_failed, request.statusText, request.responseText);
    }
  });
};

var load_more_builds = function(last_build_id, pagination, success_callback) {
  _load_builds(last_build_id, pagination, false, success_callback);
};

var load_new_builds = function(last_build_id, pagination, success_callback) {
  _load_builds(last_build_id, pagination, true, success_callback);
};

var register_build_click = function(build_entry, pagination) {
  build_entry.click(function() {
    var build_container = pagination.parent();
    build_id = build_entry.data('build_id');

    var active_entry = pagination.find('.active').removeClass('active');
    register_build_click(active_entry, pagination);
    build_entry.addClass('active');
    build_entry.unbind('click');
    pagination.data('current', build_id);

    var build = render_build(build_container, pagination.data('builds')[build_id]);

    var active_builds = build_container.find(".build:visible");
    active_builds.fadeToggle(150, function() { build.fadeToggle(150); });
  });
};

var render_pagination = function(pagination) {
  pagination.empty();
  var offset = pagination.data('offset');
  var loaded_build_ids = pagination.data('loaded_build_ids');
  var builds = pagination.data('builds');
  var has_scrolling = loaded_build_ids.length > 10;
  var count = loaded_build_ids.length - offset;
  var display_count = Math.min(count, 10);

  if (has_scrolling) {
    var previous_button = $("<li class='build_prev'><span>«</span></li>").appendTo(pagination);
    if (offset > 0) {
      previous_button.click(function() {
        pagination.data('offset', offset - 1);
        render_pagination(pagination);
      });
    } else {
      previous_button.addClass('disabled');
    }
  }

  for (var i = 0; i < display_count; i++) {
    var build = builds[loaded_build_ids[offset + i]];
    var build_entry = $("<li class='pagination_build " + status_css_class(build.status) +
        "' data-build_id='" + build.id + "'>" +
      "<span>" + build.short_identifier + "</span>" +
    "</li>").appendTo(pagination);
    if (build.id == pagination.data('current')) {
      build_entry.addClass('active');
    } else {
      register_build_click(build_entry, pagination);
    }
    // FIXME 'last_build' auszeichnen?
      //pagination.append("<li class='last_build active'><span data-target='" + last_build.id +
      //    "'>" + last_build.short_identifier + "</span></li>");
  }

  if (has_scrolling) {
    var next_button = $("<li class='build_next'><span>»</span></li>").appendTo(pagination);
    var continuation_handle = pagination.data('continuation_handle');
    var load_next = count == 10 && continuation_handle;
    if (count > 10 || load_next) {
      next_button.click(function() {
        pagination.data('offset', offset + 1);
        if (load_next) {
          load_more_builds(continuation_handle, pagination,
              function() { render_pagination(pagination); });
        } else {
          render_pagination(pagination);
        }
      });
    } else {
      next_button.addClass('disabled');
    }
  }
};

render_builds = function(container, project)
{
  var builds_element = provide_element('#builds_for_' + project.id, container, '<div/>');
  var last_build = project.last_build;
  if (last_build) {
    var pagination = provide_element(".pagination", builds_element,
        "<ul><li><div class='loading'></div></li></ul>",
        function(element) { element.data('builds', {}); });
    var builds = pagination.data('builds');
    if (_.isEmpty(builds)) {
      // init
      render_build(builds_element, last_build).show();
      builds[last_build.id] = last_build;
      pagination.data('loaded_build_ids', [last_build.id]);
      pagination.data('offset', 0);
      pagination.data('current', last_build.id);
      load_more_builds(last_build.id, pagination, function() { render_pagination(pagination); });
    } else if (!builds[last_build.id]) {
      // update
      load_new_builds(last_build.id, pagination, function() { render_pagination(pagination); });
      builds[last_build.id] = last_build;
      pagination.data('loaded_build_ids').unshift(last_build.id);
      var offset = pagination.data('offset');
      if (offset > 0) {
        pagination.data('offset', offset + 1);
      }
    }
  }
  return builds_element.show();
};


perform_project_action = function(project, action, error_message, success_handler, error_handler)
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
      show_error(error_message, request.statusText, request.responseText);
      if (error_handler) {
        error_handler();
      }
    }
  });
};


var get_data = function(locator, name) {
  return $(locator).attr('data-' + name);
};

current_user = function() {
  return get_data('#user', 'login');
};


render_project = function(project) {
  var project_column = provide_first_element("#" + project_html_id(project.id), this,
      "<div class='project col-xs-12 col-sm-6 col-md-4 col-lg-4 col-xl-3 col-xxl-2'/>");
  var project_panel = provide_element(".panel", project_column, "<div class='panel-default'/>");
  var project_heading = provide_element(".panel-heading", project_panel, "<div " +
      "data-toggle='modal' data-target='#build_dialog'/>").prop('project', project);
  var project_title = provide_element(".panel-title", project_heading,
      "<h1>" + escape_html(project.name) + "</h1>");

  var project_body = provide_element(".panel-body", project_panel, "<div>" +
      "<a href='" + project.url.replace(/^git@github.com:/, "https://github.com/") +
          "' class='github_link'>" +
        icon('github_mark') + project.url.replace(/^git@github.com:/, "") +
      "</a><br/>" +
      glyphicon('random') + project.branch + "<br/>" +
      (project.owner ? (glyphicon('user') + project.owner) : "") + "<br/>" +
      "</div>");
  update_panel_status(project_panel, project.last_build);

  var buttons = provide_element(".panel-footer", project_panel, "<div class='btn-group'/>",
      function(element) {
    $("<button class='btn btn-4 btn-danger'>" + localizer.dialog.button.delete + "</button>").
        appendTo(element).click(function() {
      bootbox.confirm(localizer.confirm.project_delete.replace('%{name}', project.name),
          function(confirmed) {
            if (confirmed) {
              perform_project_action(project, 'delete', localizer.error.delete_failed,
                  function(result) { project_column.remove(); });
            }
          });
    });
  });
  var build_button = provide_first_element(".build", buttons,
      "<button class='btn btn-4 btn-info'>" + localizer.dialog.button.build + "</button>");
  var stats_button = provide_first_element(".stats", buttons,
      "<button title='" + escape_html(localizer.project.stats.link_title) +
      "' data-project_id='" + project.id +
      "' data-project_name='" + escape_html(project.name) +
      "' class='btn btn-2 btn-default' data-toggle='modal' data-target='#stats_dialog'>◔</button>");

  if (project.build_requested) {
    build_button.prop("disabled", true);
  } else {
    build_button.prop("disabled", false);
    build_button.unbind('click');
    build_button.click(function() {
      build_button.prop("disabled", true);
      perform_project_action(project, 'build', localizer.error.trigger_build_failed, null,
          function(result) {
            build_button.prop("disabled", false);
          });
    });
  }

  // FIXME var system_error = find_project_element(project.id, 'error');
  // FIXME if (project.last_system_error) {
  // FIXME   if (system_error.length == 0) {
  // FIXME     system_error = $("<pre id='" + project_html_id(project.id, 'error') +
  // FIXME         "'></pre>").appendTo(project_box);
  // FIXME     render_log(system_error, project.last_system_error);
  // FIXME   }
  // FIXME } else {
  // FIXME   system_error.remove();
  // FIXME }

  // FIXME render_builds(project_box, project);
};


var show_all_projects = function() {
  return $("#show_all_projects").prop('checked');
};

var render_projects = function(projects) {
  var projects_element = $("#projects");

  if (!show_all_projects()) {
    projects = _.filter(projects, function(p) {
      return p.owner == null || p.owner == current_user();
    });
  }
  _.each($("#projects .project"), function(project_element) {
    project_element = $(project_element);
    var id = project_id_from_element(project_element);
    if (!_.find(projects, function(p) { return p.id == id; })) {
      project_element.remove();
    }
  });
  _.each(_.sortBy(projects, function(p) { return p.name; }).reverse(),
      render_project, projects_element);
};


var update_projects_timeout = null;
var schedule_update_projects = function() {
  if (update_projects_timeout) {
    clearTimeout(update_projects_timeout);
  }
  update_projects_timeout = setTimeout("update_projects();", 10000);
};


// FIXME Spinner
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
      show_error(localizer.error.fetch_projects_failed, request.statusText, request.responseText,
          function() {
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

var show_stats = function(project_id, container) {
  $.getJSON("/stats/project/" + project_id, function(json) {
    var data = new google.visualization.DataTable();
    data.addColumn('string', localizer.project.stats.chart.date);
    data.addColumn('number', localizer.project.stats.chart.slowest);
    data.addColumn('number', localizer.project.stats.chart.fastest);
    data.addRows(json.rows);
    var vAxis = {
      format: '# min',
      gridlines: { color: '#dfdaad', count: json.max / 5 },
      minorGridlines: { count: 5 },
      viewWindow: { max: json.max / 5 * 5, min: 0 }
    };
    new google.visualization.ColumnChart(container.get(0)).draw(data, {
      backgroundColor: '#fffacd',
      bar: { groupWidth: '70%' },
      colors: ['#77c76f', '#27771f'],
      focusTarget: 'category',
      height: '100%',
      isStacked: true,
      legend: { position: 'bottom' },
      series: [ { targetAxisIndex: 0 }, { targetAxisIndex: 1 } ],
      title: json.name + " - " + localizer.project.stats.chart.name_prefix,
      vAxes: [vAxis, vAxis],
      width: '100%'
    });
  });
};

var init_show_all_projects = function() {
  $('#show_all_projects').click(function() {
    if (this.checked) {
      this.checked = false;
      $(this).removeClass('checked').addClass('unchecked');
    } else {
      this.checked = true;
      $(this).removeClass('unchecked').addClass('checked');
    }
    update_projects();
  });
};

var init_stats_overlay = function() {
  $('#stats_dialog').on('show.bs.modal', function (evt) {
    $(evt.target).find('.modal-title').append(
        localizer.project.stats.title.replace('%{name}',
        $(evt.relatedTarget).data('project_name')));
    show_stats($(evt.relatedTarget).data('project_id'), $(evt.target).find('.modal-body'));
  });
  $('#stats_dialog').on('hidden.bs.modal', function (evt) {
    $(evt.target).find('.modal-body').empty();
    $(evt.target).find('.modal-title').empty();
  });
};

var init_error_overlay = function() {
  $("#error_overlay_close").click(function() {
    $("#error_messages").empty();
    $("#error_overlay").hide();
    _.each(error_actions, function(action) { action(); });
    error_actions = [];
  });
};

var init_modal_submit_buttons = function() {
  _.each($(".modal"), function(m) {
    $(m).find("button.submit").submit(function() {
      $(m).hide();
      return true;
    });
  });
};

var init_build_dialog = function() {
  $('#build_dialog').on('show.bs.modal', function (e) {
    $('#build_dialog .modal-title').empty().append(localizer.project.builds.title.replace('%{name}',
        escape_html(e.relatedTarget.project.name)));
    var builds = render_builds('#build_dialog .modal-body', e.relatedTarget.project);
    this['data-current_builds'] = builds.prop('id');
  });

  $('#build_dialog').on('hidden.bs.modal', function (e) {
    $("#" + this['data-current_builds']).hide();
  });
};

var add_project_is_visible = false;
var toggle_add_project_form = function() {
  var class_to_add;
  var class_to_remove;
  if (add_project_is_visible) {
    class_to_remove = "unobtrusive";
    class_to_add = "unobtrusive-disabled";
  } else {
    class_to_remove = "unobtrusive-disabled";
    class_to_add = "unobtrusive";
  }
  var container = $('#add_project');
  container.find(".form").toggle();
  container.find('a.btn').toggle();
  container.find(class_to_remove).removeClass(class_to_remove).addClass(class_to_add);
};

var reset_project_form = function() {
  var form = $("#add_project form");
  form.find("input[type=text]").prop("value", null);
  form.find(".make-switch").bootstrapSwitch('setState', true);
  toggle_add_project_form();
};

var init_add_project = function() {
  var container = $('#add_project');
  container.find('a.btn').click(function() { toggle_add_project_form(); });
  container.find('form button[type=button]').click(function() { reset_project_form(); });
  container.find("form").submit(function() {
    var form = $(this)
    var valuesToSubmit = form.serialize();
    $.ajax({
      url: form.attr('action'),
      type: 'POST',
      data: valuesToSubmit,
      dataType: "json",
      success: function(project) {
        var projects_element = $("#projects");
        var project_column = _provide_element("#" + project_html_id(project.id), projects_element,
            container,
            "<div class='project col-xs-12 col-sm-6 col-md-4 col-lg-4 col-xl-3 col-xxl-2'/>");
        $.proxy(render_project, projects_element)(project);
        reset_project_form();
      },
      error: function(request, message, exception) {
        show_error(localizer.error.create_project_failed, request.statusText, request.responseText);
      }
    });
    return false;
  });
};

var init = function() {
  init_search();
  init_show_all_projects();
  init_stats_overlay();
  init_error_overlay();
  init_modal_submit_buttons();
  init_build_dialog();
  init_add_project();
  bootbox.setDefaults({locale: language});
};

render_gui = function() {
  init();
  update_search();
  update_projects();
};
