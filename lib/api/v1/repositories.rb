# frozen_string_literal: true

module API
  module V1
    # Repositories implements all the endpoints regarding repositories and some
    # endpoints regarding tags that might be convenient to use as a
    # sub-resource.
    class Repositories < Grape::API
      version "v1", using: :path

      resource :repositories do
        before do
          authorization!(force_admin: false)
        end

        desc "Returns list of repositories",
             tags:     ["repositories"],
             detail:   "This will expose all repositories",
             is_array: true,
             entity:   API::Entities::Repositories,
             failure:  [
               [401, "Authentication fails"],
               [403, "Authorization fails"]
             ]

        get do
          present policy_scope(Repository), with: API::Entities::Repositories, type: current_type
        end

        route_param :id, type: String, requirements: { id: /.*/ } do
          resource :tags do
            ######################################################################
            ## Creates a new tag with a specified name for the selected repository
            ######################################################################
            desc "Create a new Tag for this repository",
                 consumes: ["application/x-www-form-urlencoded", "application/json"],
                 failure:  [
                   [400, "Bad request", API::Entities::ApiErrors],
                   [401, "Authentication fails"],
                   [403, "Authorization fails"],
                   [422, "Unprocessable Entity", API::Entities::FullApiErrors]
                 ]

            params do
              requires :old, type: String, documentation: { desc: "Old Tag Name" }
              requires :new, type: String, documentation: { desc: "New Tag Name" }
            end

            post do
              repo = Repository.find(params[:id])

              # Create a new tag for that repo given that new service
              res = ::Repositories::CreateTagService.new(current_user).execute(
                repo, params[:old], params[:new]
              )
              status res.code.to_i
            end
            ########################################################################

            desc "Returns the list of the tags for the given repository",
                 params:   API::Entities::Repositories.documentation.slice(:id),
                 is_array: true,
                 entity:   API::Entities::Tags,
                 failure:  [
                   [401, "Authentication fails"],
                   [403, "Authorization fails"],
                   [404, "Not found"]
                 ]

            get do
              repo = Repository.find params[:id]
              authorize repo, :show?
              present repo.tags, with: API::Entities::Tags
            end

            desc "Returns the list of the tags for the given repository groupped by digest",
                 params:   API::Entities::Repositories.documentation.slice(:id),
                 is_array: true,
                 entity:   API::Entities::Tags,
                 failure:  [
                   [401, "Authentication fails"],
                   [403, "Authorization fails"],
                   [404, "Not found"]
                 ]

            get "/grouped" do
              repo = Repository.find params[:id]
              authorize repo, :show?

              grouped_tags = repo.groupped_tags.map do |k1|
                API::Entities::Tags.represent(k1)
              end
              present grouped_tags
            end

            # NOTE: (for v2 ?) the repository ID is ignored...
            route_param :tag_id, type: String, requirements: { tag_id: /.*/ } do
              desc "Show tag by id",
                   entity:  API::Entities::Tags,
                   failure: [
                     [401, "Authentication fails"],
                     [403, "Authorization fails"],
                     [404, "Not found"]
                   ]

              params do
                requires :id, using: API::Entities::Repositories.documentation.slice(:id)
                requires :tag_id, type: String, documentation: { desc: "Tag ID" }
              end

              get do
                tag = Tag.find(params[:tag_id])
                authorize tag, :show?
                present tag, with: API::Entities::Tags
              end
            end
          end

          desc "Show repositories by id",
               entity:  API::Entities::Repositories,
               failure: [
                 [401, "Authentication fails"],
                 [403, "Authorization fails"],
                 [404, "Not found"]
               ]

          params do
            requires :id, using: API::Entities::Repositories.documentation.slice(:id)
          end

          get do
            repo = Repository.find(params[:id])
            authorize repo, :show?
            present repo,
                    with:         API::Entities::Repositories,
                    current_user: current_user,
                    type:         current_type
          end

          desc "Delete repository",
               params:  API::Entities::Repositories.documentation.slice(:id),
               failure: [
                 [401, "Authentication fails"],
                 [403, "Authorization fails"],
                 [404, "Not found"],
                 [422, "Unprocessable Entity", API::Entities::ApiErrors]
               ]

          delete do
            repository = Repository.find(params[:id])
            authorize repository, :destroy?

            destroy_service = ::Repositories::DestroyService.new(current_user)
            destroyed = destroy_service.execute(repository)

            if destroyed
              status 204
            else
              unprocessable_entity!(destroy_service.error)
            end
          end
        end
      end
    end
  end
end
