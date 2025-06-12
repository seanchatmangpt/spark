defmodule AgiFactory.Resources.QualityAssessment do
  @moduledoc """
  Quality Assessment resource for evaluating generated DSL implementations.
  
  Provides comprehensive quality evaluation including code quality,
  performance, usability, maintainability, and compliance metrics.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "quality_assessments"
    repo AgiFactory.Repo
    
    references do
      reference :dsl_project, on_delete: :delete
      reference :generation_request, on_delete: :nilify
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :assessment_type, :atom do
      description "Type of quality assessment"
      constraints [one_of: [:automatic, :manual, :hybrid, :peer_review]]
      default :automatic
    end
    
    attribute :overall_score, :decimal do
      description "Overall quality score (0-100)"
      constraints [min: 0, max: 100]
      allow_nil? false
    end
    
    attribute :code_quality_score, :decimal do
      description "Code quality and structure score"
      constraints [min: 0, max: 100]
    end
    
    attribute :performance_score, :decimal do
      description "Performance and efficiency score"
      constraints [min: 0, max: 100]
    end
    
    attribute :usability_score, :decimal do
      description "Developer experience and usability score"
      constraints [min: 0, max: 100]
    end
    
    attribute :maintainability_score, :decimal do
      description "Code maintainability score"
      constraints [min: 0, max: 100]
    end
    
    attribute :compliance_score, :decimal do
      description "Standards and best practices compliance score"
      constraints [min: 0, max: 100]
    end
    
    attribute :detailed_metrics, :map do
      description "Detailed breakdown of all quality metrics"
      default %{}
    end
    
    attribute :issues_found, {:array, :map} do
      description "List of issues identified during assessment"
      default []
    end
    
    attribute :recommendations, {:array, :string} do
      description "Recommendations for improvement"
      default []
    end
    
    attribute :assessment_duration_ms, :integer do
      description "Time taken to perform assessment in milliseconds"
      constraints [min: 0]
    end
    
    attribute :assessor_metadata, :map do
      description "Metadata about the assessment process"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    belongs_to :dsl_project, AgiFactory.Resources.DslProject do
      description "The DSL project being assessed"
      allow_nil? false
    end
    
    belongs_to :generation_request, AgiFactory.Resources.GenerationRequest do
      description "The specific generation request being assessed"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :assess_project do
      description "Performs quality assessment on a DSL project"
      accept [:assessment_type]
      
      argument :dsl_project_id, :uuid do
        description "ID of the DSL project to assess"
        allow_nil? false
      end
      
      argument :generation_request_id, :uuid do
        description "ID of the specific generation request (optional)"
      end
      
      argument :assessment_options, :map do
        description "Options for the assessment process"
        default %{}
      end
      
      change AgiFactory.Changes.ValidateAssessmentTarget
      change AgiFactory.Changes.PerformQualityAssessment
      change AgiFactory.Changes.CalculateOverallScore
      change relate_actor(:dsl_project, argument(:dsl_project_id))
      change relate_actor(:generation_request, argument(:generation_request_id))
      
      after_action AgiFactory.AfterActions.UpdateProjectQuality
    end
    
    update :add_manual_review do
      description "Adds manual review components to an automatic assessment"
      accept [:usability_score, :maintainability_score]
      
      argument :reviewer_notes, :string do
        description "Notes from the manual reviewer"
      end
      
      change AgiFactory.Changes.IncorporateManualReview
      change AgiFactory.Changes.RecalculateOverallScore
      change set_attribute(:assessment_type, :hybrid)
    end
    
    read :by_project do
      description "Read assessments for a specific project"
      
      argument :dsl_project_id, :uuid do
        description "DSL project ID"
        allow_nil? false
      end
      
      filter expr(dsl_project_id == ^arg(:dsl_project_id))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :high_quality do
      description "Read assessments with high quality scores"
      
      argument :minimum_score, :decimal do
        description "Minimum overall score threshold"
        default 80.0
      end
      
      filter expr(overall_score >= ^arg(:minimum_score))
    end
    
    read :with_issues do
      description "Read assessments that found quality issues"
      filter expr(fragment("cardinality(?) > 0", issues_found))
    end
    
    read :recent_trends do
      description "Read recent assessments for trend analysis"
      
      argument :days, :integer do
        description "Number of days back to analyze"
        default 30
      end
      
      filter expr(inserted_at >= ago(^arg(:days), :day))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :by_score_range do
      description "Read assessments within a score range"
      
      argument :min_score, :decimal do
        description "Minimum score"
        allow_nil? false
      end
      
      argument :max_score, :decimal do
        description "Maximum score"
        allow_nil? false
      end
      
      filter expr(overall_score >= ^arg(:min_score) and overall_score <= ^arg(:max_score))
    end
  end
  
  validations do
    validate {AgiFactory.Validations.ScoreConsistency, []}
    validate {AgiFactory.Validations.AssessmentCompleteness, []}
  end
  
  calculations do
    calculate :quality_grade, :string do
      description "Letter grade based on overall score"
      calculation AgiFactory.Calculations.QualityGrade
    end
    
    calculate :improvement_potential, :decimal do
      description "Potential for quality improvement"
      calculation AgiFactory.Calculations.ImprovementPotential
    end
    
    calculate :critical_issues_count, :integer do
      description "Number of critical issues found"
      calculation AgiFactory.Calculations.CriticalIssuesCount
    end
    
    calculate :assessment_efficiency, :decimal do
      description "Efficiency of the assessment process"
      calculation AgiFactory.Calculations.AssessmentEfficiency
    end
  end

  aggregates do
    count :total_issues, :issues_found do
      description "Total number of issues found"
    end
  end

  def description do
    """
    Quality Assessment provides comprehensive evaluation of generated DSL
    implementations across multiple dimensions including code quality,
    performance, usability, maintainability, and compliance.
    """
  end
end