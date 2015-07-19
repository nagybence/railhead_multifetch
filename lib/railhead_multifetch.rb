require 'action_view/digestor'


module RailheadMultifetch

  def self.included(base)
    base.class_eval do
      alias_method_chain :render_collection, :multifetch
    end
  end

  def render_collection_with_multifetch
    if @view.controller.perform_caching and (@options[:cache].present? or @locals[:cache].present?)
      return nil if @collection.blank?
      results = []
      keymap = {}
      digest = ActionView::PartialDigestor.new(name: @template.virtual_path, finder: @view.lookup_context).digest

      @collection.each do |object|
        key_base = @options[:cache].respond_to?(:call) ? @options[:cache].call(object) : object
        key = @view.controller.fragment_cache_key([key_base, digest])
        keymap[key] = object
      end
      mutable_keys = keymap.keys.map { |key| key.dup }
      cached_results = Rails.cache.read_multi(*mutable_keys)
      @collection = (keymap.keys - cached_results.keys).map { |key| keymap[key] }
      non_cached_results = @collection.present? ? collection_with_template : []
      mutable_keys.each { |key| results << (cached_results[key] || non_cached_results.shift) }

      if @options.key?(:spacer_template)
        spacer = find_template(@options[:spacer_template]).render(@view, @locals)
      end
      results.join(spacer).html_safe
    else
      render_collection_without_multifetch
    end
  end
end


ActionView::PartialRenderer.send :include, RailheadMultifetch
