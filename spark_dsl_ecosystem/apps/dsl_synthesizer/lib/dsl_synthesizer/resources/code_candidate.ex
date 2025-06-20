defmodule DslSynthesizer.Resources.CodeCandidate do
  @moduledoc """
  CodeCandidate resource representing a generated DSL implementation.
  
  A CodeCandidate is a complete DSL implementation generated by a strategy,
  including the code, quality metrics, and evaluation results.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "code_candidates"
    repo DslSynthesizer.Repo
    
    references do
      reference :generation_strategy, on_delete: :delete
      reference :quality_metrics, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :candidate_name, :string do
      description "Name of this code candidate"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :generated_code, :string do
      description "The generated DSL code"
      allow_nil? false
      constraints [min_length: 10]
    end
    
    attribute :supporting_files, :map do
      description "Additional files (tests, docs, examples)"
      default %{}
    end
    
    attribute :overall_quality_score, :decimal do
      description "Overall quality score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :compilation_status, :atom do
      description "Compilation status of the generated code"
      constraints [one_of: [:not_tested, :compiles, :compilation_errors, :compilation_warnings]]
      default :not_tested
    end
    
    attribute :test_results, :map do
      description "Results of running tests on generated code"
      default %{}
    end
    
    attribute :performance_metrics, :map do
      description "Performance metrics for the generated code"
      default %{}
    end
    
    attribute :code_metrics, :map do
      description "Static analysis metrics (complexity, coverage, etc.)"
      default %{}
    end
    
    attribute :usability_score, :decimal do
      description "Usability score based on API design (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :maintainability_score, :decimal do
      description "Maintainability score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :extensibility_score, :decimal do
      description "Extensibility score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :generation_metadata, :map do
      description "Metadata about the generation process"
      default %{}
    end
    
    attribute :optimization_applied, :boolean do
      description "Whether optimization has been applied"
      default false
    end
    
    attribute :quality_score_after_optimization, :decimal do
      description "Quality score after optimization"
      constraints [min: 0, max: 100]
    end
    
    attribute :final_status, :atom do
      description "Final status of this candidate"
      constraints [one_of: [:draft, :reviewed, :approved, :rejected, :deployed]]
      default :draft
    end
    
    attribute :reviewer_feedback, :map do
      description "Feedback from code review"
      default %{}
    end
    
    attribute :deployment_ready, :boolean do
      description "Whether this candidate is ready for deployment"
      default false
    end
    
    timestamps()
  end

  relationships do
    belongs_to :generation_strategy, DslSynthesizer.Resources.GenerationStrategy do
      description "The strategy that generated this candidate"
      attribute_writable? true
    end
    
    has_many :quality_metrics, DslSynthesizer.Resources.QualityMetrics do
      description "Detailed quality metrics for this candidate"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :generate_candidate do
      description "Generate a new code candidate"
      accept [:candidate_name, :generated_code, :generation_strategy_id]
      
      change DslSynthesizer.Changes.ValidateGeneratedCode
      change DslSynthesizer.Changes.CalculateInitialQuality
      
      after_action DslSynthesizer.AfterActions.RunInitialTests
      after_action DslSynthesizer.AfterActions.AnalyzeCodeMetrics
    end
    
    update :optimize do
      description "Optimize the code candidate"
      accept [:optimization_applied]
      
      argument :optimization_options, :map do
        description "Options for optimization"
        default %{}
      end
      
      change DslSynthesizer.Changes.ApplyOptimizations
      change DslSynthesizer.Changes.RecalculateQuality
      
      after_action DslSynthesizer.AfterActions.ValidateOptimizedCode
    end
    
    update :generate_final do
      description "Generate final production code"
      accept [:supporting_files, :deployment_ready]
      
      argument :generation_mode, :atom do
        description "Mode for final generation"
        constraints [one_of: [:development, :production, :testing]]
        default :production
      end
      
      argument :include_tests, :boolean do
        description "Include test files"
        default true
      end
      
      argument :include_documentation, :boolean do
        description "Include documentation"
        default true
      end
      
      change DslSynthesizer.Changes.GenerateSupportingFiles
      change DslSynthesizer.Changes.FinalizeCandidate
      
      after_action DslSynthesizer.AfterActions.ValidateFinalCode
    end
    
    update :review_candidate do
      description "Submit candidate for review"
      accept [:reviewer_feedback, :final_status]
      
      change DslSynthesizer.Changes.ProcessReview
    end
    
    read :by_strategy do
      description "Read candidates by generation strategy"
      
      argument :strategy_id, :uuid do
        description "Strategy ID to filter by"
        allow_nil? false
      end
      
      filter expr(generation_strategy_id == ^arg(:strategy_id))
      prepare build(sort: [overall_quality_score: :desc])
    end
    
    read :high_quality do
      description "Read high-quality candidates"
      
      argument :minimum_quality, :decimal do
        description "Minimum quality score"
        default 80.0
      end
      
      filter expr(overall_quality_score >= ^arg(:minimum_quality))
      prepare build(sort: [overall_quality_score: :desc])
    end
    
    read :deployment_ready do
      description "Read candidates ready for deployment"
      
      filter expr(deployment_ready == true and final_status == :approved)
    end
    
    read :recent do
      description "Read recent candidates"
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "7d"
      end
      
      prepare DslSynthesizer.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  validations do
    validate {DslSynthesizer.Validations.CodeValid, []}
    validate {DslSynthesizer.Validations.QualityScoresConsistent, []}
  end
  
  calculations do
    calculate :code_size, :integer do
      description "Size of generated code in characters"
      calculation DslSynthesizer.Calculations.CodeSize
    end
    
    calculate :complexity_estimate, :decimal do
      description "Estimated complexity of the generated code"
      calculation DslSynthesizer.Calculations.ComplexityEstimate
    end
    
    calculate :improvement_potential, :decimal do
      description "Potential for further improvement"
      calculation DslSynthesizer.Calculations.ImprovementPotential
    end
  end

  def description do
    """
    CodeCandidate represents a complete DSL implementation generated
    by a strategy, with comprehensive quality metrics and evaluation.
    """
  end
end