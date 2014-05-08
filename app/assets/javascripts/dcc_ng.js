// TODO
// - Keine Bucket-Logs laden, wenn Bucket collapsed
//   → beim Öffnen Laden triggern

window.onbeforeunload = function() { DCC.show_error = function() {}; };

var DCC = (function() {
  var error_actions = [];
  var error_num = 0;
  var current_user;

  var clazz = function() {
  };

  clazz.init = function(user) {
    current_user = user;
    render();
  };

  clazz.current_user = function() { return current_user; };

  var render_menubar = function() {
    $("body").append(
      '<div role="navigation" class="navbar navbar-default navbar-static-top">' +
        '<div class="container">' +
          '<div class="navbar-header">' +
            '<a class="navbar-brand">Infopark DCC</a>' +
          '</div>' +
          '<div class="collapse navbar-collapse">' +
            '<ul class="nav navbar-nav navbar-right">' +
              '<li class="dropdown" id="user">' +
                '<a href="#" class="dropdown-toggle" data-toggle="dropdown">' +
                  DCC.Localizer.t('user.welcome') + ', ' + current_user.first_name() +
                  ' <b class="caret"></b>' +
                '</a>' +
                '<ul class="dropdown-menu">' +
                  '<li>' +
                    '<a id="show_other_projects" class="btn checkbox unchecked">' +
                      DCC.HtmlUtils.glyphicon('check') +
                      DCC.Localizer.t('prefs.show_other_projects') +
                    '</a>' +
                  '</li>' +
                  '<li>' +
                    '<a id="show_shared_projects" class="btn checkbox unchecked">' +
                      DCC.HtmlUtils.glyphicon('check') +
                      DCC.Localizer.t('prefs.show_shared_projects') +
                    '</a>' +
                  '</li>' +
                  '<li class="divider"></li>' +
                  '<li>' +
                    '<a href="logout">' +
                      DCC.HtmlUtils.glyphicon('log-out') +
                      DCC.Localizer.t('user.logout') +
                    '</a>' +
                  '</li>' +
                '</ul>' +
              '</li>' +
            '</ul>' +
          '</div>' +
        '</div>' +
      '</div>'
    );

    var toggle_checkbox = function(checkbox) {
      if (checkbox.checked) {
        checkbox.checked = false;
        $(checkbox).removeClass('checked').addClass('unchecked');
      } else {
        checkbox.checked = true;
        $(checkbox).removeClass('unchecked').addClass('checked');
      }
    };

    $('#show_other_projects').click(function() {
      toggle_checkbox(this);
      DCC.ProjectView.show_other(this.checked);
    });

    $('#show_shared_projects').click(function() {
      toggle_checkbox(this);
      DCC.ProjectView.show_shared(this.checked);
    });

    if (DCC.ProjectView.show_other()) { $('#show_other_projects').click(); }
    if (DCC.ProjectView.show_shared()) { $('#show_shared_projects').click(); }
  };

  var render_container = function() {
    $("body").append(
      '<div class="container">' +
        '<div id="projects" class="row"></div>' +
      '</div>'
    );
  };

  var show_stats = function(project_id, container) {
    $.getJSON("/stats/project/" + project_id, function(json) {
      var data = new google.visualization.DataTable();
      data.addColumn('string', DCC.Localizer.t("project.stats.chart.date"));
      data.addColumn('number', DCC.Localizer.t("project.stats.chart.slowest"));
      data.addColumn('number', DCC.Localizer.t("project.stats.chart.fastest"));
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
        title: json.name + " - " + DCC.Localizer.t("project.stats.chart.name_prefix"),
        vAxes: [vAxis, vAxis],
        width: '100%'
      });
    });
  };

  var render_stats_overlay = function() {
    DCC.HtmlUtils.render_modal("stats_dialog");
    $('#stats_dialog').on('show.bs.modal', function (evt) {
      $(evt.target).find('.modal-title').append(
          DCC.Localizer.t("project.stats.title").replace('%{name}',
          $(evt.relatedTarget).data('project_name')));
      show_stats($(evt.relatedTarget).data('project_id'), $(evt.target).find('.modal-body'));
    });
    $('#stats_dialog').on('hidden.bs.modal', function (evt) {
      $(evt.target).find('.modal-body').empty();
      $(evt.target).find('.modal-title').empty();
    });
  };

  var render_error_overlay = function() {
    $("body").append(
      '<div id="error_overlay" class="error_overlay">' +
        '<h1>' + DCC.Localizer.t('error.occured') + '</h1>' +
        '<div class="error_overlay_messages_background">' +
          '<div class="error_overlay_messages_crop">' +
            '<div id="error_messages" class="error_overlay_messages panel-group">' +
            '</div>' +
            '<div id="error_overlay_close" class="error_overlay_close">' +
            '</div>' +
          '</div>' +
        '</div>' +
      '</div>'
    );
    $("#error_overlay_close").click(function() {
      $("#error_messages").empty();
      $("#error_overlay").hide();
      _.each(error_actions, function(action) { action(); });
      error_actions = [];
    });

  };

  var refresh_data = function() {
    var reschedule = function() {
      setTimeout(function() { refresh_data(); }, 10000);
    };
    DCC.Project.fetch_all(reschedule, reschedule);
  };

  var render = function() {
    render_menubar();
    render_container();
    DCC.ProjectView.init($("#projects"));
    DCC.ProjectView.render_add_project();
    DCC.ProjectBuildsView.render();
    render_stats_overlay();
    render_error_overlay();

    refresh_data();
  };

  clazz.show_error = function(headline, message, details, ok_action) {
    if (ok_action) { error_actions.push(ok_action); }

    var error_id = "error_" + error_num++;

    $('<div class="panel panel-default">').appendTo($("#error_messages")).append(
      '<div class="panel-heading">' +
        '<h4 class="panel-title">' +
          '<span data-toggle="collapse" data-parent="#error_messages" data-target="#' +
              error_id + '">' +
            DCC.HtmlUtils.escape(headline) + ": " + DCC.HtmlUtils.escape(message) +
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

  return clazz;
})();


DCC.Localizer = (function() {
  var clazz = function() {
  };

  var messages = {};
  var locale = "";

  clazz.init = function(localized_messages, current_locale) {
    messages = localized_messages;
    locale = current_locale;
    bootbox.setDefaults({locale: locale});
  };

  clazz.t = function(key) {
    var message = messages[locale];
    _.each(key.split("."), function(k) { message = message[k]; });
    return message;
  };

  return clazz;
})();


DCC.HtmlUtils = (function() {
  var clazz = function() {
  };

  var _provide_element = function(identifier, container, where, default_content, create_callback) {
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
        var css_class = identifier.substring(1);
        if (!element.hasClass(css_class)) {
          element.addClass(css_class);
        }
      }
      if (create_callback) { create_callback(element); }
    }
    return element;
  };

  clazz.provide_element = function(identifier, container, default_content, create_callback) {
    return _provide_element(identifier, container, "append", default_content, create_callback);
  };

  clazz.provide_first_element = function(identifier, container, default_content, create_callback) {
    return _provide_element(identifier, container, "prepend", default_content, create_callback);
  };

  clazz.escape = function(str) {
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

  clazz.icon = function(name, additional_class = "prefix_icon") {
    return "<i class='" + additional_class + " icon icon-" + name + "'></i>";
  }

  clazz.glyphicon = function(name, additional_class = "prefix_icon") {
    return "<i class='glyphicon glyphicon-" + name + " " + additional_class + "'></i>";
  };

  var status_message = function(status) {
    switch(status) {
      case 10:
        return DCC.Localizer.t("status.done");
      case 20:
        return DCC.Localizer.t("status.pending");
      case 30:
        return DCC.Localizer.t("status.in_work");
      case 35:
        return DCC.Localizer.t("status.processing_failed");
      case 40:
        return DCC.Localizer.t("status.failed");
      default:
        return DCC.Localizer.t("error.unknown_status + ': ' + status");
    }
  };

  clazz.status_css_class = function(status) {
    if (status <= 10) {
      return 'success';
    } else if (status <= 30) {
      return 'in_progress';
    } else {
      return 'failure';
    }
  };

  var status_icon = function(status_code) {
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

  var append_status = function(element, status_code, value, additional_title) {
    if (value != 0) {
      $("<span title='" + status_message(status_code) +
          (additional_title ? (" " + additional_title) : "") +
          "' class='" + clazz.status_css_class(status_code) + "'>" +
        clazz.glyphicon(status_icon(status_code), 'status_icon') +
        (value > 0 ? value : "") +
      "</span>").appendTo(element);
    }
  }

  var format_duration = function(interval) {
    interval /= 1000;
    var seconds = interval % 60;
    interval -= seconds;
    var minutes = interval / 60 % 60;
    interval -= minutes * 60;
    var hours = interval / 3600;
    var parts = [];
    if (hours > 0) {
      parts.push("" + hours + " " +
          DCC.Localizer.t("status.duration.hour" + (hours > 1 ? "s" : "")));
    }
    if (minutes > 0) {
      parts.push("" + minutes + " " +
          DCC.Localizer.t("status.duration.minute" + (minutes > 1 ? "s" : "")));
    }
    if (seconds > 0) {
      parts.push("" + seconds + " " +
          DCC.Localizer.t("status.duration.second" + (seconds > 1 ? "s" : "")));
    }
    return parts.join(" ");
  };


  fd = function(num)
  {
    return (num < 10 ? "0" : "") + num;
  };


  duration = function(thing)
  {
    s = ""
    if (thing.started_at()) {
      if (thing.finished_at()) {
        s = " " + DCC.Localizer.t("status.duration.in") + " " +
            format_duration(Date.parse(thing.finished_at()) - Date.parse(thing.started_at()));
      } else {
        var d = new Date(Date.parse(thing.started_at()));
        s = " " + DCC.Localizer.t("status.duration.since") + " " +
            d.getFullYear() + "-" + fd(d.getMonth() + 1) + "-" + fd(d.getDate()) + " " +
            fd(d.getHours()) + ":" + fd(d.getMinutes()) + ":" + fd(d.getSeconds());
      }
    }
    return s;
  };

  // TODO IoC: Kein 'thing' sondern anzuzeigende Daten reinreichen (via Hash).
  clazz.update_panel_status = function(panel, thing) {
    panel.removeClass("panel-danger panel-info panel-success panel-default");
    if (!thing || !thing.status()) {
      panel.addClass("panel-default");
    } else if (thing.status() <= 10) {
      panel.addClass("panel-success");
    } else if (thing.status() <= 30) {
      panel.addClass("panel-info");
    } else {
      panel.addClass("panel-danger");
    }
    if (thing) {
      var panel_status =
          DCC.HtmlUtils.provide_first_element('.indicator', panel.find('.panel-heading'),
          "<h2 class='panel-title pull-right'></h2>");
      panel_status.empty();
      if (thing.bucket_state_counts) {
        var build = thing;
        _.each([40, 35, 30, 20, 10], function(status_code) {
          var value = build.bucket_state_counts(status_code);
          append_status(panel_status, status_code, value);
        });
        var time = duration(build);
        if (time) {
          // FIXME anderes Icon als pending
          panel_status.append("<span title='" + time + "'>" +
              clazz.glyphicon('time', 'status_icon') + "</span>");
        }
      } else {
        var bucket = thing;
        append_status(panel_status, bucket.status(), null, duration(bucket));
        if (bucket.worker_hostname()) {
          panel_status.append("<span title='" + bucket.worker_hostname() + "'>" +
              clazz.icon('screen-1', 'status_icon') + "</span>");
        }
      }
    }
  };


  clazz.render_modal = function(html_id) {
    return $(
      '<div class="modal fade" id="' + html_id + '">' +
        '<div class="modal-dialog">' +
          '<div class="modal-content">' +
            '<div class="modal-header">' +
              '<button type="button" class="close" data-dismiss="modal" aria-hidden="true">' +
                '×' +
              '</button>' +
              '<h3 class="modal-title"></h3>' +
            '</div>' +
            '<div class="modal-body"></div>' +
            '<div class="modal-footer">' +
              '<button class="btn btn-default" type="button" data-dismiss="modal">' +
                DCC.Localizer.t("dialog.button.close") +
              '</button>' +
            '</div>' +
          '</div>' +
        '</div>' +
      '</div>'
    ).appendTo("body");
  };

  return clazz;
})();


DCC.User = (function() {
  var clazz = function(login, first_name, last_name) {
    this.login = function() { return login; }
    this.first_name = function() { return first_name; }
    this.last_name = function() { return last_name; }
  };

  return clazz;
})();


DCC.Project = (function() {
  var loaded_projects = {};

  var clazz = function(project_data) {
    var that = this;

    var loaded_build_ids = [];
    var builds_continuation_handle;

    this.url = function() { return project_data.url; };
    this.branch = function() { return project_data.branch; };
    this.owner = function() { return project_data.owner; };
    this.name = function() { return project_data.name; };
    this.id = function() { return project_data.id; };
    this.build_requested = function() { return project_data.build_requested; };
    this.loaded_build_ids = function() { return loaded_build_ids; }

    var last_build;
    this.last_build = function() { return last_build; };

    // TODO Build-Model → Beim Projekt-Laden direkt ein Build-Model erzeugen → multi-model-response?
    // → dann hat das project lediglich last_build_id und last_build() macht find auf Build
    // → dann muss update_panel_status entsprechend Methoden verwenden
    var load_last_build = function() {
      if (project_data.last_build) {
        new_last_build = DCC.Build.find(project_data.last_build.id);
        // TODO Wenn multi-model-response (s.o.), dann liegt der last_build als Model vor und
        // - wird das builds_continuation_handle nicht korrekt initialisiert
        // - loaded_build_ids wird nicht passend ergänzt
        // - der pagination offset wird nicht verschoben (return 1)
        if (!new_last_build) {
          if (!last_build) {
            builds_continuation_handle = project_data.last_build.id
          }
          last_build = new DCC.Build(project_data.last_build);
          loaded_build_ids.unshift(last_build.id());
          return 1;
        }
        new_last_build.update_data(project_data.last_build);
      }
      return 0;
    };
    load_last_build();

    this.destroy = function() {
      perform_post(that.id(), 'delete', {}, DCC.Localizer.t("error.delete_failed"), function() {
        handle_deleted_project(that.id());
      });
    };

    this.request_build = function(options = {}) {
      perform_post(that.id(), 'build', {}, DCC.Localizer.t("error.trigger_build_failed"),
          options.on_success, options.on_error);
    };

    var _finalize_update = function() {
      var loaded_builds = load_last_build();
      $(that).trigger("update.dcc");
      return loaded_builds;
    };

    this.update_data = function(new_project_data) {
      project_data = new_project_data;
      if (project_data.last_build && last_build && project_data.last_build.id != last_build.id()) {
        load_builds(project_data.last_build.id, true, function() { return _finalize_update(); });
      } else {
        _finalize_update();
      }
    };

    var _find_first_loaded = function(build_datas) {
      return _.find(build_datas, function(build_data) { return DCC.Build.find(build_data.id); });
    };

    var handle_loaded_builds = function(build_datas, prepend) {
      var loaded_builds = 0;
      if (prepend) {
        build_datas = build_datas.slice(0,
            build_datas.indexOf(_find_first_loaded(build_datas))).reverse();
      }
      _.each(build_datas, function(build_data) {
        if (!DCC.Build.find(build_data.id)) {
          var build = new DCC.Build(build_data);
          loaded_builds += 1;
          if (prepend) {
            loaded_build_ids.unshift(build.id());
          } else {
            loaded_build_ids.push(build.id());
          }
        }
      });
      return loaded_builds;
    };

    var load_builds = function(last_build_id, prepend, success_handler = null,
        result_handlers = []) {
      perform_get(last_build_id, "previous_builds", {},
          DCC.Localizer.t("error.fetch_builds_failed"), function(result) {
        var new_build_datas = result.previous_builds;
        result_handlers.unshift(function() {
          return handle_loaded_builds(new_build_datas, prepend);
        });
        if (prepend && new_build_datas.length &&
              !_find_first_loaded(new_build_datas) && result.continuation_handle) {
            load_builds(result.continuation_handle, true, success_handler, result_handlers);
        } else {
          var loaded_builds = _.reduce(result_handlers, function(x, h) { return x + h(); }, 0)
          if (!prepend) {
            builds_continuation_handle = result.continuation_handle;
          }
          if (success_handler) { loaded_builds += success_handler(); }
          $(that).trigger("update_builds.dcc", prepend ? loaded_builds : 0);
        }
      });
    };

    this.load_more_builds = function() {
      load_builds(builds_continuation_handle, false);
    };

    this.all_builds_loaded = function() { return !builds_continuation_handle; };
  };

  var perform_action = function(type, identifier, action, params, error_message,
      success_handler, error_handler, error_close_action) {
    // TODO Ajax-Abstraktion mit Spinner
    if (type == "POST") {
      params = _.clone(params);
      params[$('meta[name=csrf-param]').attr('content')] =
          $('meta[name=csrf-token]').attr('content');
    }

    $.ajax({
      url: '/project/' + action + (identifier ? ('/' + identifier) : ""),
      type: type,
      data: params,
      dataType: 'json',
      success: success_handler,
      error: function(request, message, exception) {
        DCC.show_error(error_message, request.statusText, request.responseText, error_close_action);
        if (error_handler) {
          error_handler();
        }
      }
    });
  };

  var perform_post =
      function(identifier, action, params, error_message, success_handler, error_handler) {
    perform_action("POST", identifier, action, params, error_message, success_handler,
        error_handler);
  };

  var perform_get = function(identifier, action, params, error_message, success_handler,
      error_close_action) {
    perform_action("GET", identifier, action, params, error_message, success_handler, null,
        error_close_action);
  };

  var handle_new_project = function(project_data) {
    var project = new DCC.Project(project_data);
    loaded_projects[project_data.id] = project;
    $(clazz).trigger("add_project.dcc", project);
  };

  var handle_deleted_project = function(id) {
    var project = loaded_projects[id];
    $(project).trigger("delete.dcc");
    delete loaded_projects[id];
  };

  clazz.fetch_all = function(success_callback, error_close_action) {
    perform_get(null, 'list', {}, DCC.Localizer.t("error.fetch_projects_failed"), function(result) {
      var vanished_project_ids = _.difference(_.keys(loaded_projects),
          _.map(result.projects, function(d) { return String(d.id); }));
      _.each(vanished_project_ids, function(id) { handle_deleted_project(id); });
      _.each(result.projects, function(project_data) {
        var loaded_project = loaded_projects[project_data.id];
        if (!loaded_project) {
          handle_new_project(project_data);
        } else {
          var new_last_build = project_data.last_build;
          var old_last_build = loaded_project.last_build();
          if (
            project_data.build_requested != loaded_project.build_requested() ||
            (
              new_last_build &&
              (
                !old_last_build ||
                old_last_build.id() != new_last_build.id ||
                old_last_build.status() != new_last_build.status ||
                old_last_build.in_work_buckets().length != new_last_build.in_work_buckets.length ||
                old_last_build.failed_buckets().length != new_last_build.failed_buckets.length ||
                old_last_build.pending_buckets().length != new_last_build.pending_buckets.length ||
                old_last_build.done_buckets().length != new_last_build.done_buckets.length
              )
            )
          ) {
            loaded_project.update_data(project_data);
          }
        }
      });
      if (success_callback) { success_callback(); }
    }, error_close_action);
  };

  clazz.find = function(id) { return loaded_projects[id]; };

  clazz.create = function(valuesToSubmit, success_callback) {
    perform_post(null, 'create', valuesToSubmit, DCC.Localizer.t("error.create_project_failed"),
        function(project_data) {
          handle_new_project(project_data);
          success_callback();
        });
  };

  return clazz;
})();


DCC.Build = (function() {
  var loaded_builds = {};

  var clazz = function(build_data) {
    var that = this;

    this.id = function() { return build_data.id; };
    this.status = function() { return build_data.status; };
    this.short_identifier = function() { return build_data.short_identifier; };
    this.in_work_buckets = function() { return build_data.in_work_buckets; };
    this.failed_buckets = function() { return build_data.failed_buckets; };
    this.pending_buckets = function() { return build_data.pending_buckets; };
    this.done_buckets = function() { return build_data.done_buckets; };
    this.bucket_state_counts = function(code) { return build_data.bucket_state_counts[code]; };
    this.started_at = function(code) { return build_data.started_at; };
    this.finished_at = function(code) { return build_data.finished_at; };

    var all_bucket_datas = function(build_data) {
      return build_data.in_work_buckets.concat(build_data.failed_buckets).concat(
          build_data.pending_buckets).concat(build_data.done_buckets);
    };

    var buckets = _.map(all_bucket_datas(build_data), function(bucket_data) {
      return new DCC.Bucket(that, bucket_data);
    });
    this.buckets = function() { return buckets; };

    loaded_builds[build_data.id] = this;

    this.update_data = function(new_build_data) {
      build_data = new_build_data;
      _.each(all_bucket_datas(new_build_data), function(bucket_data) {
        DCC.Bucket.find(bucket_data.id).update_data(bucket_data);
      });
      $(that).trigger('update.dcc');
    };
  };

  clazz.find = function(id) { return loaded_builds[id]; };

  return clazz;
})();


DCC.Bucket = (function() {
  var loaded_buckets = {};

  var clazz = function(build, bucket_data) {
    this.id = function() { return bucket_data.id; };
    this.name = function() { return bucket_data.name; };
    this.status = function() { return bucket_data.status; };
    this.build = function() { return build; };
    this.worker_hostname = function() { return bucket_data.worker_hostname; }
    this.started_at = function(code) { return bucket_data.started_at; };
    this.finished_at = function(code) { return bucket_data.finished_at; };

    this.update_data = function(new_bucket_data) { bucket_data = new_bucket_data; };

    loaded_buckets[bucket_data.id] = this;
  };

  clazz.find = function(id) { return loaded_buckets[id]; };

  return clazz;
})();


DCC.ProjectView = (function() {
  var card_css_class = "col-xs-12 col-sm-6 col-md-4 col-lg-4 col-xl-3 col-xxl-2";
  var project_views = {};
  var show_shared = true;
  var show_other = false;

  var clazz = function(container, project) {
    var that = this;
    var project_element;

    $(project).on("delete.dcc", function() {
      project_element.remove();
      delete project_views[project.id()];
    });

    $(project).on("update.dcc", function() { that.render(); });

    this.render = function() {
      project_element = DCC.HtmlUtils.provide_first_element("#project_" + project.id(),
          container, "<div class='" + card_css_class + "'/>");
      var project_panel = DCC.HtmlUtils.provide_element(".panel", project_element,
          "<div class='panel-default'/>");
      var project_heading = DCC.HtmlUtils.provide_element(".panel-heading", project_panel, "<div " +
          "data-toggle='modal' data-target='#build_dialog'/>").prop('project', project);
      var project_title = DCC.HtmlUtils.provide_element(".panel-title", project_heading,
          "<h1>" + DCC.HtmlUtils.escape(project.name()) + "</h1>");

      var project_body = DCC.HtmlUtils.provide_element(".panel-body", project_panel,
          "<div>" +
            "<a href='" + project.url().replace(/^git@github.com:/, "https://github.com/") +
                "' class='github_link'>" +
              DCC.HtmlUtils.icon('github-mark-small') +
              project.url().replace(/^git@github.com:/, "") +
            "</a><br/>" +
            DCC.HtmlUtils.glyphicon('random') + project.branch() + "<br/>" +
            (project.owner() ? (DCC.HtmlUtils.glyphicon('user') + project.owner()) : "") + "<br/>" +
          "</div>");
      DCC.HtmlUtils.update_panel_status(project_panel, project.last_build());

      var buttons = DCC.HtmlUtils.provide_element(".panel-footer", project_panel,
          "<div class='btn-group'/>", function(element) {
        $("<button class='btn btn-4 btn-danger'>" +
          DCC.Localizer.t("dialog.button.delete") +
        "</button>").appendTo(element).click(function() {
          bootbox.confirm(
            DCC.Localizer.t("confirm.project_delete").replace('%{name}', project.name),
            function(confirmed) {
              if (confirmed) {
                project.destroy();
              }
            }
          );
        });
      });
      var build_button = DCC.HtmlUtils.provide_first_element(".build", buttons,
          "<button class='btn btn-4 btn-info'>" + DCC.Localizer.t("dialog.button.build") +
          "</button>");
      var stats_button = DCC.HtmlUtils.provide_first_element(".stats", buttons,
        "<button title='" + DCC.HtmlUtils.escape(DCC.Localizer.t("project.stats.link_title")) +
            "' data-project_id='" + project.id() +
            "' data-project_name='" + DCC.HtmlUtils.escape(project.name()) +
            "' class='btn btn-2 btn-default' data-toggle='modal' data-target='#stats_dialog'>" +
          "◔" +
        "</button>"
      );

      if (project.build_requested()) {
        build_button.prop("disabled", true);
      } else {
        build_button.prop("disabled", false);
        build_button.unbind('click');
        build_button.click(function() {
          build_button.prop("disabled", true);
          project.request_build({on_error: function() { build_button.prop("disabled", false); }});
        });
      }

      that.adjust_visibility(0);
    };

    this.adjust_visibility = function(duration = 150) {
      var should_be_hidden = (
        (project.owner() == null && !show_shared) ||
        (project.owner() != null && project.owner() != DCC.current_user().login() && !show_other)
      );
      if (should_be_hidden == $(project_element).is(":visible")) {
        $(project_element).fadeToggle(duration);
      }
    };
  };

  var toggle_add_project_form = function() {
    var container = $('#add_project');
    container.find(".form").toggle();
    container.find('a.btn').toggle();
    container.find('.panel-footer').toggleClass("hidden");
    container.find('.panel-body').toggleClass('unobtrusive');
  };

  var reset_add_project_form = function() {
    var form = $("#add_project form");
    form.find("input[type=text]").prop("value", null);
    form.find(".make-switch").bootstrapSwitch('setState', true);
    toggle_add_project_form();
  };

  var init_add_project = function() {
    var container = $('#add_project');
    container.find('a.btn').click(function() { toggle_add_project_form(); });
    container.find('form button[type=button]').click(function() { reset_add_project_form(); });
    container.find('.make-switch').bootstrapSwitch();
    container.find("form").submit(function() {
      var params = {};
      _.each($(this).serializeArray(), function(param) {
        if (params[param.name]) {
          params[param.name] = _.flatten([params[param.name], param.value]);
        } else {
          params[param.name] = param.value;
        }
      });
      DCC.Project.create(params, function() { reset_add_project_form() });
      return false;
    });
  };

  var projects_container;
  clazz.init = function(container) {
    projects_container = container;
    $(DCC.Project).on("add_project.dcc", function(e, project) {
      (project_views[project.id()] = new DCC.ProjectView(projects_container, project)).render();
    });
  };

  clazz.render_add_project = function() {
    $(projects_container).append(
      '<div id="add_project" class="' + card_css_class + '">' +
        '<form accept-charset="UTF-8">' +
          '<div class="panel panel-default add_project">' +
            '<div class="panel-heading">' +
              '<span class="form">' +
                '<input id="project_name" type="text" size="30" placeholder="' +
                    DCC.Localizer.t('project.name') + '" name="project[name]"/>' +
              '</span>' +
            '</div>' +
            '<div class="panel-body unobtrusive">' +
              '<span class="form">' +
                DCC.HtmlUtils.icon('github-mark-small') +
                '<input id="project_url" type="text" size="30" placeholder="' +
                    DCC.Localizer.t('project.url') + '" name="project[url]"/><br/>' +
                DCC.HtmlUtils.glyphicon('random') +
                '<input id="project_branch" type="text" size="30" placeholder="' +
                    DCC.Localizer.t('project.branch') + '" name="project[branch]"/><br/>' +
                DCC.HtmlUtils.glyphicon('user') +
                '<div class="make-switch switch-small" data-on-label="' +
                    DCC.Localizer.t("project.personal") + '" data-off-label="' +
                    DCC.Localizer.t("project.shared") + '">' +
                  '<input id="project_personal" type="checkbox" checked="checked" ' +
                      'name="project[personal]"/>' +
                '</div>' +
              '</span>' +
              '<div class="show_form_button">' +
                '<a class="btn">' +
                  DCC.HtmlUtils.glyphicon('plus', 'large_icon') + '<br/>' +
                  DCC.Localizer.t("project.new") +
                '</a>' +
              '</div>' +
            '</div>' +
            '<div class="panel-footer btn-group hidden">' +
              '<button type="button" class="btn btn-default btn-5 btn-default">' +
                DCC.Localizer.t("dialog.button.cancel") +
              '</button>' +
              '<button type="submit" class="btn btn-default btn-5 btn-primary">' +
                DCC.Localizer.t("dialog.button.create") +
              '</button>' +
            '</div>' +
          '</div>' +
        '</form>' +
      '</div>'
    );
    init_add_project();
  };

  var adjust_visibility = function() {
    _.each(project_views, function(view) { view.adjust_visibility(); });
  };

  clazz.show_other = function(value) {
    if (value != undefined) {
      show_other = value;
      adjust_visibility();
    }
    return show_other;
  }

  clazz.show_shared = function(value) {
    if (value != undefined) {
      show_shared = value;
      adjust_visibility();
    }
    return show_shared;
  }

  return clazz;
})();


DCC.ProjectBuildsView = (function() {
  var dialog;
  var current_view;
  var views = {};

  var clazz = function(project) {
    var that = this;
    var offset = 0;
    var current;
    var identifier = "#builds_for_" + project.id();
    var pagination;
    var build_views = {};
    var builds_container;
    var next_button;

    $(project).on("update_builds.dcc", function(e, prepended_count) {
      if (offset > 0) {
        offset += prepended_count;
      }
      render_pagination();
    });

    // TODO eigentlich ist das hier $(build).on für alle Builds in der Pagination, die weiß ich aber
    // derzeit nicht. Wäre wohl auch etwas overdosed … project.update tut es aktuell wunderbar.
    $(project).on("update.dcc", function() { render_pagination(); });

    var register_build_click = function(build_entry, build) {
      build_entry.click(function() {
        var active_entry = pagination.find('.active').removeClass('active');
        register_build_click(active_entry, DCC.Build.find(current));
        build_entry.addClass('active');
        build_entry.unbind('click');

        var previous = current;

        current = build.id();
        if (!build_views[current]) {
          build_views[current] = new DCC.BuildView(builds_container, build);
          build_views[current].render();
        }
        build_views[previous].fade_to(build_views[current]);
      });
    };

    var load_more_builds = function() {
      next_button.unbind('click');
      next_button.addClass("disabled");
      next_button.find("span").addClass("loading");
      project.load_more_builds();
    };

    var render_pagination = function(force_next) {
      if (!pagination) { return; }
      pagination.empty();
      var has_scrolling = project.loaded_build_ids().length > 10;
      var count = project.loaded_build_ids().length - offset;
      var display_count = Math.min(count, 10);

      if (has_scrolling) {
        var previous_button = $("<li class='build_prev'><span>«</span></li>").appendTo(pagination);
        if (offset > 0) {
          previous_button.click(function() {
            offset -= 1;
            render_pagination();
          });
        } else {
          previous_button.addClass('disabled');
        }
      }

      for (var i = 0; i < display_count; i++) {
        var build = DCC.Build.find(project.loaded_build_ids()[offset + i]);
        var build_entry = $("<li class='pagination_build " +
            DCC.HtmlUtils.status_css_class(build.status()) + "'>" +
          "<span>" + build.short_identifier() + "</span>" +
        "</li>").appendTo(pagination);
        if (build.id() == current) {
          build_entry.addClass('active');
        } else {
          register_build_click(build_entry, build);
        }
      }

      if (has_scrolling || force_next) {
        next_button = $("<li class='build_next'><span>»</span></li>").appendTo(pagination);
        var load_next = count == 10 && !project.all_builds_loaded();
        if (count > 10 || load_next) {
          next_button.click(function() {
            offset += 1;
            if (load_next) {
              load_more_builds();
            } else {
              render_pagination();
            }
          });
        } else {
          next_button.addClass('disabled');
        }
      }
    };

    this.render = function() {
      dialog.find('.modal-title').empty().append(
          DCC.Localizer.t("project.builds.title").replace('%{name}',
          DCC.HtmlUtils.escape(project.name())));

      builds_container = DCC.HtmlUtils.provide_element(identifier,
          dialog.find(".modal-body"), '<div/>');
      var last_build = project.last_build();
      if (last_build && !pagination) {
        current = last_build.id();
        // TODO generischer Ansatz für die View-based-Spinner
        pagination = DCC.HtmlUtils.provide_element(".pagination", builds_container,
            "<ul><li><div class='loading'></div></li></ul>");
        build_views[current] = new DCC.BuildView(builds_container, last_build);
        build_views[current].render();
        build_views[current].show();
        render_pagination(true);
        load_more_builds();
      } else {
        render_pagination();
      }
      builds_container.show();
    };

    this.hide = function() { $(identifier).hide(); };
  };

  clazz.for_project = function(project) {
    if (!views[project.id()]) {
      views[project.id()] = new DCC.ProjectBuildsView(project);
    }
    return views[project.id()];
  };

  clazz.render = function() {
    dialog = DCC.HtmlUtils.render_modal("build_dialog");
    dialog.on('show.bs.modal', function (e) {
      current_view = DCC.ProjectBuildsView.for_project(e.relatedTarget.project);
      current_view.render();
    });

    dialog.on('hidden.bs.modal', function (e) {
      current_view.hide();
    });
  };

  return clazz;
})();


DCC.BuildView = (function() {
  var clazz = function(container, build) {
    var that = this;

    var bucket_views = {};
    var buckets_container;

    $(build).on("update.dcc", function() { render_buckets(); });

    var render_buckets = function() {
      var sorted_views = _.sortBy(_.sortBy(bucket_views, function(bucket_view) {
        return bucket_view.bucket().name();
      }), function(bucket_view) {
        return -bucket_view.bucket().status();
      });
      _.each(sorted_views, function(bucket_view) { bucket_view.render(); });
    };

    this.render = function() {
      buckets_container = DCC.HtmlUtils.provide_element("#build_" + build.id(), container,
          "<div class='build panel-group'/>");
      buckets_container.hide();
      _.each(build.buckets(), function(bucket) {
        bucket_views[bucket.id()] = new DCC.BucketView(buckets_container, bucket);
      });
      render_buckets();
    };

    this.show = function() { $(buckets_container).fadeIn(150); };
    this.fade_to = function(other) { $(buckets_container).fadeOut(150, other.show); };
  };

  return clazz;
})();


DCC.BucketView = (function() {
  var clazz = function(container, bucket) {
    var log_container;

    this.bucket = function() { return bucket; };

    var render_log = function(log) { log_container.append(DCC.HtmlUtils.escape(log)); };

    // TODO daten/view trennen
    // TODO Project-Action
    var update_log = function() {
      $.ajax({
        url: '/project/log/' + bucket.id(),
        dataType: 'json',
        success: function(result) {
          log_container.empty();
          if (result.log) {
            render_log(result.log);
          } else {
            _.each(result.logs, function(log) { render_log(log); });
            setTimeout(function() { update_log(); }, 5000);
          }
        },
        error: function(request, message, exception) {
          DCC.show_error(DCC.Localizer.t("error.fetch_log_failed"), request.statusText,
              request.responseText, function() {
            setTimeout(function() { update_log(); }, 5000);
          });
        }
      });
    };

    this.render = function() {
      var bucket_box = DCC.HtmlUtils.provide_element("#bucket_" + bucket.id(), container,
        '<div class="panel panel-default bucket ' + DCC.HtmlUtils.status_css_class(bucket) +
            '" data-bucket_id="' + bucket.id() + '">' +
          '<div class="panel-heading" data-toggle="collapse"' +
              ' data-parent="#build_' + bucket.build().id() + '"' +
              ' data-target="#log_' + bucket.id() + '">' +
            '<h4 class="panel-title">' +
              DCC.HtmlUtils.escape(bucket.name()) +
            '</h4>' +
          '</div>' +
        '</div>', function(element) {
          element.on('show.bs.collapse', function (evt) {
            update_log();
            element.unbind('show.bs.collapse');
          });
        }
      );
      var bucket_segment = DCC.HtmlUtils.provide_element("#log_" + bucket.id(), bucket_box,
          '<div class="panel-collapse collapse">');
      var bucket_body = DCC.HtmlUtils.provide_element(".panel-body", bucket_segment, "<div/>");
      log_container = DCC.HtmlUtils.provide_element("pre", bucket_body,
          '<pre><div class="loading"></div></pre>');
      DCC.HtmlUtils.update_panel_status(bucket_box, bucket);
      // Alle Buckets werden immer zusammen gerendert (in der richtigen Reihenfolge).
      // → Das hier sorgt für die richtige Reihenfolge im DOM.
      // Sauberer wäre das natürlich im Build-View…
      container.append(bucket_box)
    };
  };

  return clazz;
})();
