debug = "nix";

window.onbeforeunload = function() { DCC.show_error = function() {}; };

var DCC = (function() {
  var error_actions = [];
  var error_num = 0;

  var clazz = function(user) {
    var that = this;

    this.current_user = function() { return user; };


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
                    DCC.Localizer.t('user.welcome') + ', ' + that.current_user().first_name() +
                    ' <b class="caret"></b>' +
                  '</a>' +
                  '<ul class="dropdown-menu">' +
                    '<li>' +
                      '<a class="btn checkbox unchecked" id="show_all_projects">' +
                        '<i class="prefix_icon glyphicon glyphicon-check"></i>' +
                        DCC.Localizer.t('prefs.show_all_projects') +
                      '</a>' +
                    '</li>' +
                    '<li class="divider"></li>' +
                    '<li><a href="logout">' +
                      '<i class="prefix_icon glyphicon glyphicon-log-out"></i>' +
                      DCC.Localizer.t('user.logout') +
                    '</a></li>' +
                  '</ul>' +
                '</li>' +
              '</ul>' +
            '</div>' +
          '</div>' +
        '</div>'
      );
    };

    var render_container = function() {
      $("body").append(
        '<div class="container">' +
          '<div id="projects" class="row"></div>' +
        '</div>'
      );
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

    var projects_container = function() { return $("#projects"); };

    var handle_add_project = function(e, project) {
      new DCC.ProjectView(projects_container(), project).render();
    };

    var register_event_handlers = function() {
      projects_container().on("add_project.dcc", handle_add_project);
    };

    var refresh_data = function() {
      var reschedule = function() {
        setTimeout(function() { refresh_data(); }, 10000);
      };
      DCC.Project.fetch_all(reschedule, reschedule);
    };

    this.render = function() {
      render_menubar();
      render_container();
      DCC.ProjectView.render_add_project(projects_container());
      DCC.HtmlUtils.render_modal("stats_dialog");
      DCC.ProjectBuildsView.render();
      render_error_overlay();

      register_event_handlers();

      // TODO stattdessen add-Event auf DCC.Project triggern und ProjectView via init darauf
      // abonnieren → keine register_event_handlers und keine handle_add_project
      DCC.Project.init(projects_container());

      refresh_data();
    };
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

  clazz.compute_id = function(class_name, id, specifier) {
    var suffix = "";
    if (specifier) {
      suffix = "_" + specifier;
    }
    return class_name + "_" + id + suffix;
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

  clazz.icon = function(name) {
    return "<i class='prefix_icon icon icon-" + name + "'></i>";
  }

  clazz.glyphicon = function(name, additional_class) {
    additional_class = additional_class || "prefix_icon"
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

  var append_status = function(element, status_code, value) {
    if (value != 0) {
      $("<span title='" + status_message(status_code) +
          "' class='" + clazz.status_css_class(status_code) + "'>" +
        clazz.glyphicon(status_icon(status_code), 'status_icon') +
        (value > 0 ? value : "") +
      "</span>").appendTo(element);
    }
  }

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
          var value = build.bucket_state_counts(status_code.toString());
          append_status(panel_status, status_code, value);
        });
      } else {
        append_status(panel_status, thing.status());
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
      // TODO Wenn multi-model-response (s.o.), dann liegt der last_build als Model vor und kann bei
      // load_builds nicht mehr als „bitte nachladen“-Indikator verwendet werden.
      if (project_data.last_build && !DCC.Build.find(project_data.last_build.id)) {
        if (!last_build) {
          builds_continuation_handle = project_data.last_build.id
        }
        last_build = new DCC.Build(project_data.last_build);
        loaded_build_ids.unshift(last_build.id());
        return 1;
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

    var handle_loaded_builds = function(build_datas, prepend) {
      var loaded_builds = 0;
      _.each(prepend ? build_datas.reverse() : build_datas, function(build_data) {
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
              !DCC.Build.find(_.last(new_build_datas).id) && result.continuation_handle) {
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

  var container;
  clazz.init = function(projects_container) {
    container = projects_container;
  };

  var handle_new_project = function(project_data) {
    var project = new DCC.Project(project_data);
    loaded_projects[project_data.id] = project;
    container.trigger("add_project.dcc", project);
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
        } else if (
          project_data.build_requested != loaded_project.build_requested() ||
          (
            project_data.last_build &&
            (
              !loaded_project.last_build() ||
              loaded_project.last_build().id() != project_data.last_build.id ||
              loaded_project.last_build().status() != project_data.last_build.status
            )
          )
        ) {
          loaded_project.update_data(project_data);
        }
      });
      if (success_callback) { success_callback(); }
    }, error_close_action);
  };

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

    var load_buckets = function(bucket_datas) {
      return _.map(bucket_datas, function(bucket_data) {
        return new DCC.Bucket(that, bucket_data);
      });
    };

    var buckets = load_buckets(build_data.in_work_buckets).concat(
        load_buckets(build_data.failed_buckets)).concat(
        load_buckets(build_data.pending_buckets)).concat(
        load_buckets(build_data.done_buckets));
    this.buckets = function() { return buckets; };

    loaded_builds[build_data.id] = this;
  };

  // TODO Update Builds:
  // - alle Builds, die noch nicht fertig sind, müssen regelmässig aktualisiert werden
  // - auch ihre Buckets!

  clazz.find = function(id) {
    return loaded_builds[id];
  };

  return clazz;
})();


DCC.Bucket = (function() {
  var clazz = function(build, bucket_data) {
    this.id = function() { return bucket_data.id; };
    this.name = function() { return bucket_data.name; };
    this.status = function() { return bucket_data.status; };
    this.build = function() { return build; };
  };

  return clazz;
})();


DCC.ProjectView = (function() {
  var card_css_class = "col-xs-12 col-sm-6 col-md-4 col-lg-4 col-xl-3 col-xxl-2";

  var clazz = function(container, project) {
    var that = this;
    var html_id = DCC.HtmlUtils.compute_id(project.id());

    $(project).on("delete.dcc", function() { $("#" + html_id).remove(); });

    $(project).on("update.dcc", function() { that.render(); });

    this.render = function() {
      var project_column = DCC.HtmlUtils.provide_first_element("#" + html_id,
          container, "<div class='" + card_css_class + "'/>");
      var project_panel = DCC.HtmlUtils.provide_element(".panel", project_column,
          "<div class='panel-default'/>");
      var project_heading = DCC.HtmlUtils.provide_element(".panel-heading", project_panel, "<div " +
          "data-toggle='modal' data-target='#build_dialog'/>").prop('project', project);
      var project_title = DCC.HtmlUtils.provide_element(".panel-title", project_heading,
          "<h1>" + DCC.HtmlUtils.escape(project.name()) + "</h1>");

      var project_body = DCC.HtmlUtils.provide_element(".panel-body", project_panel,
          "<div>" +
            "<a href='" + project.url().replace(/^git@github.com:/, "https://github.com/") +
                "' class='github_link'>" +
              DCC.HtmlUtils.icon('github_mark') + project.url().replace(/^git@github.com:/, "") +
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

  clazz.render_add_project = function(container) {
    $(container).append(
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
                '<i class="prefix_icon icon icon-github_mark"></i>' +
                '<input id="project_url" type="text" size="30" placeholder="' +
                    DCC.Localizer.t('project.url') + '" name="project[url]"/><br/>' +
                '<i class="prefix_icon glyphicon glyphicon-random"></i>' +
                '<input id="project_branch" type="text" size="30" placeholder="' +
                    DCC.Localizer.t('project.branch') + '" name="project[branch]"/><br/>' +
                '<i class="prefix_icon glyphicon glyphicon-user"></i>' +
                '<div class="make-switch switch-small" data-on-label="' +
                    DCC.Localizer.t("project.personal") + '" data-off-label="' +
                    DCC.Localizer.t("project.shared") + '">' +
                  '<input id="project_personal" type="checkbox" checked="checked" ' +
                      'name="project[personal]"/>' +
                '</div>' +
              '</span>' +
              '<div class="show_form_button">' +
                '<a class="btn">' +
                  '<i class="glyphicon glyphicon-plus"></i><br/>' +
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

    $(project).on("update_builds.dcc", function(e, prepended_count) {
      if (offset > 0) {
        offset += prepended_count;
      }
      render_pagination();
    });

    var register_build_click = function(build_entry, build) {
      build_entry.click(function() {
        // TODO schöner (instanzvariable)
        var build_container = pagination.parent();

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

    var render_pagination = function() {
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

      if (has_scrolling) {
        var next_button = $("<li class='build_next'><span>»</span></li>").appendTo(pagination);
        var load_next = count == 10 && !project.all_builds_loaded();
        if (count > 10 || load_next) {
          next_button.click(function() {
            offset += 1;
            if (load_next) {
              project.load_more_builds();
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
        project.load_more_builds();
      }
      render_pagination();
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

    var render_buckets = function() {
      // TODO: das ist initial state
      // → update entweder komplett neu rendern, oder dom sortieren
      // → dom sortieren geht auch ohne jquery extension: views sortieren, und dann
      //   each.view_element.parentNode.appendChild(view_element)
      // TODO Bucket-Updates:
      // - Umsortierung der Liste
      // - Aktualisierung des Status
      // - Log-Update
      // - kein Log-Update mehr, wenn fertig
      // - kein Bucket-Update von fertigen Buckets
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
      // TODO Update via event
      render_buckets();
    };

    this.show = function() { $(buckets_container).fadeIn(150); };
    this.fade_to = function(other) { $(buckets_container).fadeOut(150, other.show); };
  };

  return clazz;
})();


DCC.BucketView = (function() {
  var clazz = function(container, bucket) {
    this.bucket = function() { return bucket; };

    this.render = function() {
      // FIXME log-HTML-ID wofür?
      var html_id = "bucket_" + bucket.id() + "_log";
      // FIXME
      // - Zusatzinfo (auf Rechner x) mit schickem Icon (Compi) davor rechts im Header
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
          '<div id="log_' + bucket.id() + '" class="panel-collapse collapse">' +
            '<div class="panel-body">' +
              "<pre id='" + html_id + "'>" +
                '<div class="loading"></div>' +
              "</pre>" +
            '</div>' +
          '</div>' +
        '</div>', function(element) {
          element.on('show.bs.collapse', function (evt) {
            // FIXME
            //update_log(bucket.id);
            element.unbind('show.bs.collapse');
          });
        }
      );
      // FIXME kein update, wenn nicht pending/in_work
      DCC.HtmlUtils.update_panel_status(bucket_box, bucket);
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
  };

  return clazz;
})();
