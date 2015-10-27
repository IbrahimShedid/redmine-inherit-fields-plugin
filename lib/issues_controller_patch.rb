
module SubtasksInheritedFields
  module IssuesControllerPatch
    module InstanceMethods

      #redefine create method to call our redirect_after_create
      def create_plugin
        call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
        @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
        if @issue.save
          call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
          respond_to do |format|
            format.html {
              render_attachment_warning_if_needed(@issue)
              flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
              redirect_after_create #redirect after create inheriting subtask fields
            }
            format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
          end
          return
        else
          respond_to do |format|
            format.html { render :action => 'new' }
            format.api  { render_validation_errors(@issue) }
          end
        end
      end

      # Redirects user after a successful issue creation with inheritance
      def redirect_after_create
        if params[:continue]

          attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}

          #inherit fields on create subtask and continue
          if @issue.parent_issue_id
            settings = Setting.find_by_name("plugin_redmine_subtasks_inherited_fields") || {}
            settings = settings.value if settings.respond_to? :value
            settings = {} if settings == ""
            if settings[:inherit_tracker_id] #inherit tracker
              attrs[:tracker_id] = @issue.tracker
            else #use default subtask tracker
              default_tracker = Tracker.find_by_id(settings[:default_tracker_id] || 0) || @issue.tracker
              default_tracker = @issue.tracker unless @project.trackers.include? default_tracker
              attrs[:tracker_id] = default_tracker
            end
            attrs[:fixed_version_id] = @issue.fixed_version_id if settings[:inherit_fixed_version_id]
            attrs[:category_id] = @issue.category_id if settings[:inherit_category_id]
            attrs[:assigned_to_id] = @issue.assigned_to_id if settings[:inherit_assigned_to_id]
            attrs[:priority_id] = @issue.priority_id if settings[:inherit_priority_id]
            attrs[:start_date] = @issue.start_date if settings[:inherit_start_date]
            attrs[:due_date] = @issue.due_date if settings[:inherit_due_date]
            attrs[:description] = @issue.description if settings[:inherit_description]
            attrs[:is_private] = @issue.is_private if settings[:inherit_is_private]
            attrs[:status_id] = @issue.status_id if settings[:inherit_status_id]
  
            #inherit custom fields
            inherit_custom_fields = settings[:inherit_custom_fields] || {}
            unless inherit_custom_fields.empty?
              custom_field_values = {}
              @issue.custom_field_values.each do |v|
                custom_field_values[v.custom_field_id] = v.value if inherit_custom_fields[v.custom_field_id.to_s]
              end
  
              attrs[:custom_field_values] = custom_field_values unless custom_field_values.empty?
            end
          end

          if params[:project_id]
            redirect_to new_project_issue_path(@issue.project, :issue => attrs)
          else
            attrs.merge! :project_id => @issue.project_id
            redirect_to new_issue_path(:issue => attrs)
          end
        else
          redirect_to issue_path(@issue)
        end
      end
    end

    def self.included(receiver)
      receiver.send :include, InstanceMethods
 
      receiver.class_eval do
        unloadable
        alias_method :create, :create_plugin
      end
    end
  end
end

unless IssuesController.included_modules.include?(SubtasksInheritedFields::IssuesControllerPatch)
  #puts "Including module into IssuesController"
  IssuesController.send(:include, SubtasksInheritedFields::IssuesControllerPatch)
end

