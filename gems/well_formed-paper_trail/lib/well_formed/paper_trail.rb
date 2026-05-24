# frozen_string_literal: true

module WellFormed
  module PaperTrail
    @whodunnit = nil

    class << self
      # Global default whodunnit proc, used when no per-form +paper_trail_whodunnit+ is set.
      # The proc receives the form's +user+ as its argument.
      #
      #   WellFormed::PaperTrail.whodunnit = ->(user) { user&.email }
      #
      attr_accessor :whodunnit
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.set_callback(:save, :around, :_with_paper_trail) if base.respond_to?(:_save_callbacks)
      base.set_callback(:perform, :around, :_with_paper_trail) if base.respond_to?(:_perform_callbacks)
    end

    module ClassMethods
      # Override the whodunnit value set on PaperTrail.request during save/perform.
      # The block is evaluated in the context of the form instance, so form attributes
      # and helpers (including +user+) are available.
      #
      #   paper_trail_whodunnit { user.email }
      #   paper_trail_whodunnit { "admin:#{user.id}" }
      #
      # Defaults to +user&.id&.to_s+ when not set.
      def paper_trail_whodunnit(&block)
        @_paper_trail_whodunnit = block
      end

      def _paper_trail_whodunnit_proc
        return @_paper_trail_whodunnit if defined?(@_paper_trail_whodunnit)

        superclass._paper_trail_whodunnit_proc if superclass.respond_to?(:_paper_trail_whodunnit_proc)
      end
    end

    private

    def _with_paper_trail
      whodunnit = if (proc = self.class._paper_trail_whodunnit_proc)
        instance_exec(&proc)
      elsif (global = WellFormed::PaperTrail.whodunnit)
        global.call(user)
      else
        user&.id&.to_s
      end
      ::PaperTrail.request(whodunnit: whodunnit) { yield }
    end
  end
end
