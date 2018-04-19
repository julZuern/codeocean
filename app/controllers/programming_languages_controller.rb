class ProgrammingLanguagesController < ApplicationController
  def authorize!
    authorize(@programming_language || @programming_languages)
  end
  private :authorize!

  def versions
    @programming_languages = ProgrammingLanguage.where(name: params[:proglang])
    authorize!
    versions = @programming_languages.select(:version).distinct.to_json
    respond_to do |format|
      format.json { render json: versions}
    end
  end

  def show
    @programming_language = ProgrammingLanguage.find(params[:id])
    authorize!
    respond_to do |format|
      if @programming_language
        format.json {render json: @programming_language}
      else
        format.json {render json: {errors: t('activerecord.errors.programming_languages.error_message')}, status: :unprocessable_entity}
      end
    end
  end

  def create
    @programming_language = ProgrammingLanguage.find_or_initialize_by(name: params[:name], version: params[:version])
    authorize!
    saved = @programming_language.save
    respond_to do |format|
      if saved && @programming_language.check_default(params[:is_default])
          format.json { render json: @programming_language }
      elsif saved
          format.json { render json: {error: @programming_language.errors.full_messages}}
      else
        format.json { render json: {errors: @programming_language.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end
end