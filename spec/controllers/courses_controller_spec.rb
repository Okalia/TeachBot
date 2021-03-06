require 'rails_helper'

RSpec.describe CoursesController, type: :controller do
  include ActiveJob::TestHelper

  describe 'GET #show' do
    before :each do
      @course = create(:course)
      Services::Access::RecentVisit.new(request.remote_ip, @course).clear
    end
    # access_to_course? helper already prevents all possible unexpected access to course
    it 'add views and add popular_tags jobs' do
      expect do
        get :show, params: { id: @course.friendly_id }
        expect(response).to have_http_status(:success)
      end.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
    end
  end

  describe 'POST #create' do
    before :each do
      @user = create(:teacher)
      @course_params = {
        title:       'testCourseTitle',
        description: 'testCourseDescription',
        public:      true
      }
    end

    it 'denies access for no guests' do
      post :create, params: {
        course: @course_params
      }

      expect(response).to have_http_status(302)
      expect(Course.count).to be 0
    end

    it 'denies access for no teacher' do
      auth_as(create(:second_user))

      post :create, params: {
        course: @course_params
      }

      expect(response).to have_http_status(302)
      expect(Course.count).to be 0
    end

    it 'creates the course' do
      auth_as(@user)

      user = create(:teacher, username: 'harahaiha', email: 'god@mail.ru')
      puts user.roles.to_json

      post :create, params: {
        course: @course_params
      }

      expect(response).to have_http_status(302)
      expect(Course.count).to be 1
    end

    it 'creates tags' do
      auth_as(@user)

      set_json_request

      tags_param = 'test1,test2'
      tags = { tags_list: tags_param }

      @course_params.merge! tags

      post :create, params: {
        course: @course_params
      }

      expect(response).to have_http_status(302)

      course = Course.first
      expect(course.tags.size).to eq 2

      assert (course.tags.pluck(:name) - tags_param.split(',')).empty?
    end

    it 'returns error if fail validation' do
      auth_as(@user)

      set_json_request

      # at the moment, max length - 30 chars
      tags_param = SecureRandom.base58(31)
      tags = { tags_list: tags_param }

      @course_params.merge! tags

      post :create, params: {
        course: @course_params
      }

      expect(response).to have_http_status(422)
      expect(response.body).to match(/Tags has invalid tag/)
    end
  end

  describe 'PUT #update' do
    before :each do
      @course = create(:course)
    end
    it 'denies access for guests' do
      put :update, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)
    end

    it 'denies access for no teacher' do
      foreign_user = create(:second_user)

      auth_as(foreign_user)

      put :update, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)

      set_json_request

      put :update, params: { id: @course.friendly_id }
      expect(response.body).to match(/You are not a teacher/)
      expect(response).to have_http_status(403)
    end

    it 'denies access for no owner' do
      foreign_user = create(:second_user)
      foreign_user.add_role(:teacher)

      auth_as(foreign_user)

      put :update, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)

      set_json_request

      put :update, params: { id: @course.friendly_id }
      expect(response.body).to match(/Access denied/)
      expect(response).to have_http_status(403)
    end

    it 'accepts access for teacher and owner' do
      auth_as(@course.author) # it calls 'teacher' factory in the factories

      course_title = @course.title
      expect(@course.title).to eq(course_title)

      new_title = 'UPDATED title'
      put :update, params: { id: @course.friendly_id, course: { title: new_title } }
      expect(response).to have_http_status(302)
      @course.reload
      expect(@course.title).to eq(new_title)
    end

    it 'creates tags' do
      auth_as(@course.author)
      assert_equal @course.tags.size, 0

      set_json_request

      tags = 'test1,test2'

      put :update, params: {
        id:     @course.friendly_id,
        course: {
          tags_list: tags
        }
      }

      expect(response).to have_http_status(302)
      @course.reload
      expect(@course.tags.size).to eq 2

      expect((@course.tags.pluck(:name) - tags.split(',')).empty?).to be true
    end

    it 'returns error if fail validation' do
      auth_as(@course.author)
      assert_equal @course.tags.size, 0

      set_json_request

      # at the moment, max length - 30 chars
      tags = SecureRandom.base58(31)

      put :update, params: {
        id:     @course.friendly_id,
        course: {
          tags_list: tags
        }
      }

      expect(response).to have_http_status(422)
      expect(response.body).to match(/Tags has invalid tag/)
    end

    it 'replaces old tags with new' do
      auth_as(@course.author)
      @course.tags << [Tag.new(name: 'oldTag1'), Tag.new(name: 'oldTag2')]

      @course.reload

      assert_equal @course.tags.size, 2

      set_json_request

      tags = 'test1,test2'

      put :update, params: {
        id:     @course.friendly_id,
        course: {
          tags_list: tags
        }
      }

      expect(response).to have_http_status(302)

      @course.reload

      assert_equal @course.tags.size, 2

      expect((@course.tags.pluck(:name) - tags.split(',')).size).to be 0
    end
  end

  describe 'DELETE #destroy' do
    before :each do
      @course = create(:course)
    end
    it 'denies access for guests' do
      delete :destroy, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)
    end

    it 'denies access for no teacher' do
      foreign_user = create(:second_user)

      auth_as(foreign_user)

      delete :destroy, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)

      set_json_request

      delete :destroy, params: { id: @course.friendly_id }
      expect(response.body).to match(/You are not a teacher/)
      expect(response).to have_http_status(403)
    end

    it 'denies access for no owner' do
      foreign_user = create(:second_user)
      foreign_user.add_role(:teacher)

      auth_as(foreign_user)

      delete :destroy, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)

      set_json_request

      delete :destroy, params: { id: @course.friendly_id }
      expect(response.body).to match(/Access denied/)
      expect(response).to have_http_status(403)
    end

    it 'accepts access for teacher and owner' do
      auth_as(@course.author) # it calls 'teacher' factory in the factories
      expect(Course.exists?(@course.id)).to eq(true)

      delete :destroy, params: { id: @course.friendly_id }
      expect(response).to have_http_status(302)
      expect(Course.exists?(@course.id)).to eq(false)
    end
  end

  describe 'PATCH #update_poster' do
    before :each do
      @course = create(:course)
    end
    it 'do redirect if guest' do
      patch :update_poster, params: { id: @course.id }
      expect(response.status).to eq(302)
    end

    it 'denies access for foreign user' do
      foreign_user = create(:second_user)
      foreign_user.add_role(:teacher)

      auth_as(foreign_user)

      patch :update_poster, params: { id: @course.id }
      expect(response.status).to eq(302)

      set_json_request

      patch :update_poster, params: { id: @course.id }
      expect(response.status).to eq(403)
      expect(response.body).to match(/Access denied/)
    end

    it 'returns error if file is not presented' do
      auth_as(@course.author)

      patch :update_poster, params: { id: @course.id }
      expect(response.status).to eq(302)

      set_json_request

      patch :update_poster, params: { id: @course.id }
      expect(response.status).to eq(422)
      expect(response.body).to match(/File not found/)
    end

    it 'returns error if file is invalid' do
      auth_as(@course.author)

      file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'file.txt'), 'image/png')
      patch :update_poster, params: { id: @course.id, course: { poster: file } }
      expect(response.status).to eq(422)
      expect(response.body).to match(/Impossible to get width of the file/)
    end

    it 'returns appropriate error message if the file is too height' do
      auth_as(@course.author)
      file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'too_height_poster.jpg'), 'image/png')
      patch :update_poster, params: { id: @course.id, course: { poster: file } }
      expect(response.status).to eq(422)
      expect(response.body).to match(/Height is too high/)
    end

    it 'returns appropriate error message if the file is too width' do
      auth_as(@course.author)
      file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'too_width_poster.jpg'), 'image/png')
      patch :update_poster, params: { id: @course.id, course: { poster: file } }
      expect(response.status).to eq(422)
      expect(response.body).to match(/Width is too high/)
    end

    it 'returns success if file is valid' do
      auth_as(@course.author)

      file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'valid_poster.jpg'), 'image/png')
      patch :update_poster, params: { id: @course.id, course: { poster: file } }
      expect(response.body).to match(/Poster has been created successfully/)
      expect(response.status).to eq(200)
    end
  end
end
