from __future__ import annotations

import hashlib
import json
import random
import re
from dataclasses import dataclass
from itertools import combinations
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CONTENT_ROOT = ROOT / "content"
MANIFEST_PATH = ROOT / "manifest.json"
ROLE_PAGE_LIMIT = 125
MIN_BODY_WORDS = 800


@dataclass(frozen=True)
class RoleProfile:
    slug: str
    title: str
    category: str


@dataclass(frozen=True)
class ParserProfile:
    slug: str
    title: str
    strengths: tuple[str, ...]
    weak_points: tuple[str, ...]
    preferred_format: str
    recruiter_view: str


@dataclass(frozen=True)
class SkillTarget:
    slug: str
    title: str
    category: str


@dataclass(frozen=True)
class ToolProfile:
    slug: str
    title: str
    primary_keyword: str
    core_question: str
    inputs: tuple[str, ...]
    outputs: tuple[str, ...]
    scoring_signals: tuple[str, ...]


@dataclass(frozen=True)
class DatasetProfile:
    industry_slug: str
    industry_title: str
    family_slug: str
    family_title: str
    category: str


@dataclass
class SeoPage:
    url_path: str
    page_type: str
    primary_keyword: str
    seo_title: str
    meta_description: str
    h1: str
    body: str

    @property
    def output_path(self) -> Path:
        relative = self.url_path.lstrip("/") + ".md"
        return CONTENT_ROOT / relative


CATEGORY_PROFILES: dict[str, dict[str, object]] = {
    "backend": {
        "core_skills": ("APIs", "PostgreSQL", "Redis", "Docker", "AWS"),
        "keyword_clusters": ("REST API", "authentication", "query optimization", "observability", "CI/CD"),
        "recruiter_focus": "clean architecture, production reliability, and measurable service outcomes",
        "weak_bullet": "Worked on backend features and bug fixes.",
        "strong_bullet": "Built FastAPI services and optimized PostgreSQL queries; reduced p95 latency by 29% on customer-facing endpoints.",
        "common_failures": ("tool lists with no proof", "vague scale descriptions", "missing ownership verbs"),
        "metrics": ("latency", "throughput", "error rate", "release speed"),
        "top_headings": ("Experience", "Skills", "Projects", "Education"),
    },
    "frontend": {
        "core_skills": ("React", "TypeScript", "JavaScript", "CSS", "Accessibility"),
        "keyword_clusters": ("component architecture", "design systems", "performance", "testing", "responsive UI"),
        "recruiter_focus": "shipping interfaces that are fast, maintainable, and accessible",
        "weak_bullet": "Helped build the web app UI.",
        "strong_bullet": "Built React and TypeScript flows for onboarding; lifted completion by 17% after reducing interaction friction.",
        "common_failures": ("visual claims without outcomes", "generic UI wording", "missing performance evidence"),
        "metrics": ("conversion", "bundle size", "Core Web Vitals", "task completion"),
        "top_headings": ("Experience", "Skills", "Projects", "Design Systems"),
    },
    "fullstack": {
        "core_skills": ("TypeScript", "Node.js", "React", "SQL", "AWS"),
        "keyword_clusters": ("end-to-end delivery", "API integration", "database design", "deployment", "debugging"),
        "recruiter_focus": "breadth plus enough depth to own features across the stack",
        "weak_bullet": "Worked on frontend and backend tickets.",
        "strong_bullet": "Delivered React dashboards and Node.js APIs for subscription reporting; cut analyst turnaround from one day to one hour.",
        "common_failures": ("broad stack claims with no scope", "duplicated bullet language", "no system boundaries"),
        "metrics": ("cycle time", "defect rate", "query time", "activation"),
        "top_headings": ("Experience", "Skills", "Projects", "Tooling"),
    },
    "data": {
        "core_skills": ("SQL", "Python", "Tableau", "Power BI", "Excel"),
        "keyword_clusters": ("data modeling", "dashboards", "forecasting", "A/B testing", "stakeholder reporting"),
        "recruiter_focus": "analytical rigor, clean metric definitions, and business translation",
        "weak_bullet": "Created reports for the business team.",
        "strong_bullet": "Built SQL and Tableau reporting for retention cohorts; reduced manual reporting time by 8 hours per week.",
        "common_failures": ("tool-only skills sections", "no business outcomes", "undefined metrics"),
        "metrics": ("time saved", "accuracy", "forecast variance", "adoption"),
        "top_headings": ("Experience", "Skills", "Projects", "Certifications"),
    },
    "data-engineering": {
        "core_skills": ("Python", "SQL", "Airflow", "dbt", "Snowflake"),
        "keyword_clusters": ("pipelines", "orchestration", "warehousing", "data quality", "lineage"),
        "recruiter_focus": "reliable data movement, clean models, and low-maintenance delivery",
        "weak_bullet": "Maintained data pipelines.",
        "strong_bullet": "Rebuilt Airflow ingestion and dbt models in Snowflake; cut failed runs by 43% and improved freshness for weekly reporting.",
        "common_failures": ("no scale details", "no data quality language", "warehouse skills without model examples"),
        "metrics": ("freshness", "pipeline failure rate", "runtime", "cost per run"),
        "top_headings": ("Experience", "Skills", "Projects", "Data Stack"),
    },
    "ml": {
        "core_skills": ("Python", "PyTorch", "TensorFlow", "MLOps", "Feature Engineering"),
        "keyword_clusters": ("model deployment", "evaluation", "monitoring", "experimentation", "inference"),
        "recruiter_focus": "production-ready models, not only notebooks",
        "weak_bullet": "Built machine learning models.",
        "strong_bullet": "Deployed a PyTorch ranking model with feature monitoring; improved precision at top results while reducing inference cost.",
        "common_failures": ("research wording with no deployment path", "missing evaluation context", "framework names without use cases"),
        "metrics": ("precision", "recall", "latency", "inference cost"),
        "top_headings": ("Experience", "Skills", "Projects", "Research"),
    },
    "product": {
        "core_skills": ("Roadmapping", "Experimentation", "User Research", "Analytics", "Stakeholder Management"),
        "keyword_clusters": ("prioritization", "discovery", "go-to-market", "funnel metrics", "cross-functional leadership"),
        "recruiter_focus": "decision quality, outcome thinking, and cross-team execution",
        "weak_bullet": "Managed product roadmap and team communication.",
        "strong_bullet": "Prioritized onboarding experiments using funnel data; lifted activation by 11% while reducing engineering churn.",
        "common_failures": ("task language instead of impact", "missing product metrics", "unclear decision ownership"),
        "metrics": ("activation", "retention", "NPS", "win rate"),
        "top_headings": ("Experience", "Skills", "Projects", "Leadership"),
    },
    "marketing": {
        "core_skills": ("SEO", "GA4", "HubSpot", "Content Strategy", "Campaign Analysis"),
        "keyword_clusters": ("conversion", "attribution", "pipeline", "retention", "channel mix"),
        "recruiter_focus": "demand generation plus evidence of commercial impact",
        "weak_bullet": "Ran marketing campaigns across channels.",
        "strong_bullet": "Built lifecycle campaigns in HubSpot and GA4; increased demo-qualified leads by 22% over one quarter.",
        "common_failures": ("channel lists without results", "no attribution language", "soft verbs"),
        "metrics": ("CTR", "pipeline", "CAC", "conversion rate"),
        "top_headings": ("Experience", "Skills", "Campaigns", "Tools"),
    },
    "sales": {
        "core_skills": ("Prospecting", "CRM", "Pipeline Management", "Discovery", "Negotiation"),
        "keyword_clusters": ("quota attainment", "forecast accuracy", "deal cycle", "expansion", "objection handling"),
        "recruiter_focus": "revenue, consistency, and territory execution",
        "weak_bullet": "Handled outbound sales and client communication.",
        "strong_bullet": "Managed outbound pipeline in Salesforce; exceeded quarterly quota by 18% through tighter discovery and follow-up sequencing.",
        "common_failures": ("no quota context", "missing CRM proof", "generic relationship language"),
        "metrics": ("quota", "ACV", "win rate", "sales cycle"),
        "top_headings": ("Experience", "Skills", "Results", "Tools"),
    },
    "design": {
        "core_skills": ("Figma", "Wireframing", "Design Systems", "Prototyping", "Usability Testing"),
        "keyword_clusters": ("user flows", "interaction design", "research synthesis", "handoff", "accessibility"),
        "recruiter_focus": "clarity of design thinking and evidence of product impact",
        "weak_bullet": "Designed screens for the product team.",
        "strong_bullet": "Mapped new checkout flows in Figma and usability tests; reduced abandonment in the final step of purchase.",
        "common_failures": ("aesthetic language with no business effect", "missing research detail", "no handoff evidence"),
        "metrics": ("completion rate", "task time", "usability score", "conversion"),
        "top_headings": ("Experience", "Skills", "Projects", "Portfolio Highlights"),
    },
    "finance": {
        "core_skills": ("Excel", "Financial Modeling", "Forecasting", "Variance Analysis", "ERP"),
        "keyword_clusters": ("budgeting", "close process", "cash flow", "controls", "scenario planning"),
        "recruiter_focus": "accuracy, control, and decision support",
        "weak_bullet": "Supported finance operations and reporting.",
        "strong_bullet": "Built rolling forecasts and variance models; improved month-end visibility for department leaders.",
        "common_failures": ("no ownership language", "unclear reporting cadence", "missing systems"),
        "metrics": ("forecast accuracy", "close time", "cost savings", "cash visibility"),
        "top_headings": ("Experience", "Skills", "Systems", "Certifications"),
    },
    "operations": {
        "core_skills": ("Process Improvement", "SOPs", "Reporting", "Vendor Management", "Capacity Planning"),
        "keyword_clusters": ("throughput", "SLAs", "cross-functional coordination", "resource planning", "cost control"),
        "recruiter_focus": "structured execution and operational efficiency",
        "weak_bullet": "Helped improve operations processes.",
        "strong_bullet": "Redesigned intake workflows and reporting; reduced turnaround time and tightened SLA adherence.",
        "common_failures": ("generic efficiency claims", "missing process language", "no measurable before-and-after"),
        "metrics": ("cycle time", "SLA hit rate", "cost per unit", "backlog"),
        "top_headings": ("Experience", "Skills", "Processes", "Systems"),
    },
    "security": {
        "core_skills": ("SIEM", "Incident Response", "IAM", "Vulnerability Management", "Cloud Security"),
        "keyword_clusters": ("detection", "response", "hardening", "risk reduction", "compliance"),
        "recruiter_focus": "security outcomes, not only tool familiarity",
        "weak_bullet": "Handled security tasks and investigations.",
        "strong_bullet": "Tuned SIEM detections and response playbooks; reduced mean time to triage for high-severity alerts.",
        "common_failures": ("tool lists without scenarios", "no severity context", "compliance with no control evidence"),
        "metrics": ("MTTR", "false positives", "coverage", "risk reduction"),
        "top_headings": ("Experience", "Skills", "Certifications", "Controls"),
    },
    "it": {
        "core_skills": ("Windows", "Linux", "Networking", "Help Desk", "Endpoint Management"),
        "keyword_clusters": ("ticket resolution", "user support", "device management", "identity", "SLA"),
        "recruiter_focus": "speed, reliability, and escalation judgment",
        "weak_bullet": "Provided IT support to employees.",
        "strong_bullet": "Resolved escalated endpoint and identity issues; improved first-response time while keeping ticket quality high.",
        "common_failures": ("support language with no service metrics", "missing systems", "unclear escalation scope"),
        "metrics": ("first response", "resolution time", "CSAT", "backlog"),
        "top_headings": ("Experience", "Skills", "Systems", "Certifications"),
    },
    "legal": {
        "core_skills": ("Contract Review", "Legal Research", "Compliance", "Case Management", "Document Drafting"),
        "keyword_clusters": ("risk review", "negotiation support", "regulatory analysis", "filings", "policy"),
        "recruiter_focus": "accuracy, judgment, and document quality",
        "weak_bullet": "Assisted with legal documents and research.",
        "strong_bullet": "Reviewed commercial contract terms and research memos; improved turnaround for sales and procurement stakeholders.",
        "common_failures": ("generic document wording", "no domain language", "missing matter scope"),
        "metrics": ("turnaround time", "review volume", "risk flags", "accuracy"),
        "top_headings": ("Experience", "Skills", "Practice Areas", "Education"),
    },
    "healthcare": {
        "core_skills": ("Patient Care", "EHR", "Care Coordination", "Clinical Documentation", "Compliance"),
        "keyword_clusters": ("triage", "medication", "care plans", "patient safety", "regulatory standards"),
        "recruiter_focus": "safety, documentation quality, and patient outcomes",
        "weak_bullet": "Provided patient support and documentation.",
        "strong_bullet": "Managed patient intake and clinical documentation in the EHR while supporting safe handoffs across the care team.",
        "common_failures": ("soft care language without scope", "missing EHR terms", "unclear certifications"),
        "metrics": ("patient volume", "documentation accuracy", "handoff quality", "wait time"),
        "top_headings": ("Experience", "Skills", "Licenses", "Education"),
    },
    "education": {
        "core_skills": ("Curriculum Design", "Assessment", "Classroom Management", "Instruction", "Learning Outcomes"),
        "keyword_clusters": ("lesson planning", "student progress", "instructional design", "differentiation", "stakeholder communication"),
        "recruiter_focus": "outcomes, planning quality, and learning impact",
        "weak_bullet": "Taught students and prepared lessons.",
        "strong_bullet": "Designed lesson plans and tracked assessment outcomes; improved student progress against weekly learning goals.",
        "common_failures": ("job duties with no outcome framing", "missing standards language", "weak assessment detail"),
        "metrics": ("student growth", "attendance", "completion", "assessment results"),
        "top_headings": ("Experience", "Skills", "Certifications", "Education"),
    },
    "admin": {
        "core_skills": ("Scheduling", "Calendar Management", "Travel Coordination", "Documentation", "Office Systems"),
        "keyword_clusters": ("executive support", "meeting logistics", "workflow organization", "vendor coordination", "confidentiality"),
        "recruiter_focus": "reliability, prioritization, and operational support",
        "weak_bullet": "Handled admin work for the office.",
        "strong_bullet": "Managed calendar, meeting logistics, and travel planning; reduced scheduling conflicts for senior leaders.",
        "common_failures": ("generic office language", "no stakeholder scope", "missing systems detail"),
        "metrics": ("scheduling accuracy", "response time", "support volume", "process consistency"),
        "top_headings": ("Experience", "Skills", "Systems", "Education"),
    },
}


PARSER_PROFILES: list[ParserProfile] = [
    ParserProfile("workday", "Workday", ("structured sections", "plain date ranges", "clear skills lists"), ("sidebars", "text boxes", "split dates"), "DOCX or clean PDF", "a parsed candidate profile with extracted titles, dates, and skills"),
    ParserProfile("greenhouse", "Greenhouse", ("reverse chronology", "clean contact details", "simple bullets"), ("headers with key data", "complex tables", "graphic skill bars"), "clean PDF", "resume text beside structured fields and keyword search"),
    ParserProfile("lever", "Lever", ("plain section labels", "direct job titles", "consistent tool names"), ("nested columns", "creative headings", "logo-heavy resumes"), "PDF with strong text layer", "searchable candidate cards with attached resume context"),
    ParserProfile("taleo", "Taleo", ("standard headings", "simple chronology", "exact keywords"), ("columns", "icons", "decorative date placement"), "DOCX", "structured candidate records and filtered search results"),
    ParserProfile("icims", "iCIMS", ("skills grouped by type", "clear employer names", "plain bullets"), ("floating text", "badly exported PDFs", "ambiguous headings"), "DOCX or clean PDF", "indexed profiles with recruiter filters"),
    ParserProfile("smartrecruiters", "SmartRecruiters", ("clean summaries", "tool repetition with proof", "project sections"), ("table layouts", "badge-only skills", "dense headers"), "clean PDF", "resume preview plus parsed metadata"),
    ParserProfile("bamboohr", "BambooHR", ("simple sections", "consistent dates", "straightforward bullets"), ("resume graphics", "footers with contact data", "non-standard headings"), "DOCX", "lightweight candidate records and attachment review"),
    ParserProfile("jobvite", "Jobvite", ("clear role titles", "plain keywords", "reverse chronology"), ("split columns", "icons near headings", "weak text extraction"), "PDF or DOCX", "recruiter search with title and skill filters"),
    ParserProfile("workable", "Workable", ("short summaries", "clean section order", "specific skills"), ("text boxes", "columns", "graphic timelines"), "clean PDF", "searchable profiles with parsed fields"),
    ParserProfile("sap-successfactors", "SAP SuccessFactors", ("exact terminology", "simple layout", "consistent employer formatting"), ("tables", "visual skill meters", "header-only contact details"), "DOCX", "enterprise recruiter search and extracted fields"),
    ParserProfile("adp-recruiting", "ADP Recruiting", ("plain bullets", "standard headings", "keyword repetition"), ("multi-column resumes", "styled headers", "non-text logos"), "DOCX", "candidate profiles filtered by keyword and recent title"),
    ParserProfile("oracle-recruiting-cloud", "Oracle Recruiting Cloud", ("clean chronology", "skills in plain text", "simple file structure"), ("PDFs with broken text layers", "creative headings", "date alignment tricks"), "DOCX or clean PDF", "parsed candidate search records"),
    ParserProfile("ukg-pro-recruiting", "UKG Pro Recruiting", ("simple section labels", "clear certifications", "plain contact data"), ("icons", "side panels", "header-only summaries"), "DOCX", "structured search with attached resume view"),
    ParserProfile("avature", "Avature", ("clean formatting", "searchable keywords", "clear experience blocks"), ("complex templates", "badge clouds", "unclear project labels"), "clean PDF", "talent database search and recruiter snapshots"),
    ParserProfile("bullhorn", "Bullhorn", ("role titles", "client-facing outcomes", "plain skills"), ("graphic-heavy templates", "weird date ordering", "long unbroken paragraphs"), "DOCX", "staffing recruiter search and quick skim views"),
    ParserProfile("jazzhr", "JazzHR", ("standard headings", "reverse chronology", "exact skill names"), ("two-column designs", "icons in headings", "fragmented PDFs"), "PDF", "small-team recruiter scans with filtered candidate lists"),
    ParserProfile("recruitee", "Recruitee", ("plain summaries", "simple bullets", "consistent keyword spelling"), ("visual timelines", "mixed heading styles", "tables"), "clean PDF", "collaborative recruiter notes plus parsed resume fields"),
    ParserProfile("ashby", "Ashby", ("structured experience", "project context", "role-relevant keywords"), ("graphic layouts", "dense sidebars", "missing section labels"), "PDF or DOCX", "searchable profile records and panel review"),
    ParserProfile("teamtailor", "Teamtailor", ("short summaries", "clear titles", "simple files"), ("header graphics", "multi-column exports", "soft heading names"), "PDF", "candidate cards plus text extraction"),
    ParserProfile("breezy-hr", "Breezy HR", ("standard labels", "clean skills blocks", "simple dates"), ("table-based layouts", "decorative separators", "icons"), "DOCX", "parsed candidate lists and quick recruiter scans"),
    ParserProfile("pinpoint", "Pinpoint", ("simple structure", "exact role terms", "good chronology"), ("visual skill bars", "floating contact details", "creative section naming"), "clean PDF", "searchable talent profiles"),
    ParserProfile("applicantstack", "ApplicantStack", ("plain text sections", "clear certifications", "stable file formats"), ("headers with key data", "date split across lines", "logos instead of text"), "DOCX", "parsed application records"),
    ParserProfile("paylocity-recruiting", "Paylocity Recruiting", ("clean work history", "simple contact blocks", "plain skill lists"), ("columns", "rating bars", "image-based PDFs"), "DOCX or clean PDF", "keyword search and structured records"),
    ParserProfile("clearcompany", "ClearCompany", ("direct titles", "consistent month-year ranges", "simple summaries"), ("badge-only skills", "project text boxes", "graphic dividers"), "clean PDF", "ATS search and recruiter preview"),
    ParserProfile("cornerstone-recruiting", "Cornerstone Recruiting", ("standard sections", "keyword coverage", "plain formatting"), ("complex templates", "multi-column layouts", "footer-only contact data"), "DOCX", "enterprise candidate search and profile extraction"),
]


PARSER_FOCUS = [
    {"slug": "resume-format", "page_type": "parser_specific_ats_guide", "title_pattern": "{parser} ATS Resume Format Checklist", "h1_pattern": "{parser} ATS Resume Format: What Actually Passes", "primary_pattern": "{parser} ATS resume format", "angle": "format", "section_title": "Resume Formatting Issues That Break {parser} Parsing"},
    {"slug": "pdf-vs-docx", "page_type": "parser_specific_ats_guide", "title_pattern": "{parser} PDF vs DOCX for ATS", "h1_pattern": "{parser} ATS: PDF vs DOCX Resume Choice", "primary_pattern": "{parser} PDF vs DOCX ATS", "angle": "file format", "section_title": "When {parser} Reads PDF Better Than DOCX"},
    {"slug": "keyword-matching", "page_type": "parser_specific_ats_guide", "title_pattern": "{parser} ATS Keyword Matching Guide", "h1_pattern": "{parser} ATS Keyword Matching: What Gets Found", "primary_pattern": "{parser} ATS keyword matching", "angle": "keyword matching", "section_title": "Keyword Placement That {parser} Actually Understands"},
    {"slug": "section-headings", "page_type": "parser_specific_ats_guide", "title_pattern": "{parser} ATS Section Headings Guide", "h1_pattern": "{parser} ATS Section Headings That Parse Cleanly", "primary_pattern": "{parser} ATS section headings", "angle": "headings", "section_title": "Section Headings {parser} Usually Reads Correctly"},
    {"slug": "date-parsing", "page_type": "parser_specific_ats_guide", "title_pattern": "{parser} ATS Date Parsing Checklist", "h1_pattern": "{parser} ATS Date Parsing: Fix Resume Timeline Errors", "primary_pattern": "{parser} ATS date parsing", "angle": "dates", "section_title": "Date Formatting That Prevents {parser} Timeline Errors"},
]


SKILL_TARGETS: list[SkillTarget] = [
    SkillTarget("backend-engineer", "Backend Engineer", "backend"),
    SkillTarget("data-analyst", "Data Analyst", "data"),
    SkillTarget("product-manager", "Product Manager", "product"),
    SkillTarget("marketing-manager", "Marketing Manager", "marketing"),
    SkillTarget("account-executive", "Account Executive", "sales"),
]


SKILLS = [
    "Python",
    "SQL",
    "Excel",
    "React",
    "TypeScript",
    "AWS",
    "Docker",
    "Kubernetes",
    "Terraform",
    "Salesforce",
    "HubSpot",
    "Tableau",
    "Power BI",
    "Figma",
    "GA4",
    "FastAPI",
    "Spring Boot",
    "dbt",
    "Snowflake",
    "Selenium",
]


ROLE_PROFILES: list[RoleProfile] = [
    RoleProfile("software-engineer", "Software Engineer", "fullstack"),
    RoleProfile("backend-engineer", "Backend Engineer", "backend"),
    RoleProfile("frontend-engineer", "Frontend Engineer", "frontend"),
    RoleProfile("full-stack-developer", "Full Stack Developer", "fullstack"),
    RoleProfile("ios-developer", "iOS Developer", "frontend"),
    RoleProfile("android-developer", "Android Developer", "frontend"),
    RoleProfile("mobile-developer", "Mobile Developer", "frontend"),
    RoleProfile("platform-engineer", "Platform Engineer", "backend"),
    RoleProfile("site-reliability-engineer", "Site Reliability Engineer", "backend"),
    RoleProfile("devops-engineer", "DevOps Engineer", "backend"),
    RoleProfile("cloud-engineer", "Cloud Engineer", "backend"),
    RoleProfile("security-engineer", "Security Engineer", "security"),
    RoleProfile("network-engineer", "Network Engineer", "it"),
    RoleProfile("systems-administrator", "Systems Administrator", "it"),
    RoleProfile("database-administrator", "Database Administrator", "backend"),
    RoleProfile("qa-engineer", "QA Engineer", "frontend"),
    RoleProfile("automation-qa-engineer", "Automation QA Engineer", "frontend"),
    RoleProfile("embedded-software-engineer", "Embedded Software Engineer", "backend"),
    RoleProfile("game-developer", "Game Developer", "frontend"),
    RoleProfile("solutions-architect", "Solutions Architect", "backend"),
    RoleProfile("data-analyst", "Data Analyst", "data"),
    RoleProfile("business-analyst", "Business Analyst", "data"),
    RoleProfile("data-engineer", "Data Engineer", "data-engineering"),
    RoleProfile("analytics-engineer", "Analytics Engineer", "data-engineering"),
    RoleProfile("data-scientist", "Data Scientist", "ml"),
    RoleProfile("machine-learning-engineer", "Machine Learning Engineer", "ml"),
    RoleProfile("research-scientist", "Research Scientist", "ml"),
    RoleProfile("bi-analyst", "BI Analyst", "data"),
    RoleProfile("financial-analyst", "Financial Analyst", "finance"),
    RoleProfile("operations-analyst", "Operations Analyst", "operations"),
    RoleProfile("product-manager", "Product Manager", "product"),
    RoleProfile("senior-product-manager", "Senior Product Manager", "product"),
    RoleProfile("technical-product-manager", "Technical Product Manager", "product"),
    RoleProfile("project-manager", "Project Manager", "product"),
    RoleProfile("program-manager", "Program Manager", "product"),
    RoleProfile("scrum-master", "Scrum Master", "product"),
    RoleProfile("agile-coach", "Agile Coach", "product"),
    RoleProfile("customer-success-manager", "Customer Success Manager", "sales"),
    RoleProfile("implementation-manager", "Implementation Manager", "operations"),
    RoleProfile("product-operations-manager", "Product Operations Manager", "operations"),
    RoleProfile("marketing-manager", "Marketing Manager", "marketing"),
    RoleProfile("growth-marketing-manager", "Growth Marketing Manager", "marketing"),
    RoleProfile("product-marketing-manager", "Product Marketing Manager", "marketing"),
    RoleProfile("content-marketing-manager", "Content Marketing Manager", "marketing"),
    RoleProfile("seo-specialist", "SEO Specialist", "marketing"),
    RoleProfile("paid-media-specialist", "Paid Media Specialist", "marketing"),
    RoleProfile("email-marketing-specialist", "Email Marketing Specialist", "marketing"),
    RoleProfile("social-media-manager", "Social Media Manager", "marketing"),
    RoleProfile("community-manager", "Community Manager", "marketing"),
    RoleProfile("brand-manager", "Brand Manager", "marketing"),
    RoleProfile("account-executive", "Account Executive", "sales"),
    RoleProfile("sales-development-representative", "Sales Development Representative", "sales"),
    RoleProfile("business-development-manager", "Business Development Manager", "sales"),
    RoleProfile("sales-manager", "Sales Manager", "sales"),
    RoleProfile("customer-support-specialist", "Customer Support Specialist", "sales"),
    RoleProfile("solutions-consultant", "Solutions Consultant", "sales"),
    RoleProfile("customer-onboarding-specialist", "Customer Onboarding Specialist", "sales"),
    RoleProfile("ux-designer", "UX Designer", "design"),
    RoleProfile("ui-designer", "UI Designer", "design"),
    RoleProfile("product-designer", "Product Designer", "design"),
    RoleProfile("ux-researcher", "UX Researcher", "design"),
    RoleProfile("graphic-designer", "Graphic Designer", "design"),
    RoleProfile("motion-designer", "Motion Designer", "design"),
    RoleProfile("content-designer", "Content Designer", "design"),
    RoleProfile("instructional-designer", "Instructional Designer", "education"),
    RoleProfile("technical-writer", "Technical Writer", "design"),
    RoleProfile("copywriter", "Copywriter", "marketing"),
    RoleProfile("accountant", "Accountant", "finance"),
    RoleProfile("senior-accountant", "Senior Accountant", "finance"),
    RoleProfile("controller", "Controller", "finance"),
    RoleProfile("auditor", "Auditor", "finance"),
    RoleProfile("tax-analyst", "Tax Analyst", "finance"),
    RoleProfile("fp-and-a-analyst", "FP&A Analyst", "finance"),
    RoleProfile("bookkeeper", "Bookkeeper", "finance"),
    RoleProfile("compliance-analyst", "Compliance Analyst", "legal"),
    RoleProfile("risk-analyst", "Risk Analyst", "finance"),
    RoleProfile("fraud-analyst", "Fraud Analyst", "finance"),
    RoleProfile("hr-generalist", "HR Generalist", "operations"),
    RoleProfile("recruiter", "Recruiter", "operations"),
    RoleProfile("talent-acquisition-specialist", "Talent Acquisition Specialist", "operations"),
    RoleProfile("people-operations-manager", "People Operations Manager", "operations"),
    RoleProfile("office-manager", "Office Manager", "admin"),
    RoleProfile("administrative-assistant", "Administrative Assistant", "admin"),
    RoleProfile("executive-assistant", "Executive Assistant", "admin"),
    RoleProfile("operations-manager", "Operations Manager", "operations"),
    RoleProfile("business-operations-manager", "Business Operations Manager", "operations"),
    RoleProfile("program-operations-manager", "Program Operations Manager", "operations"),
    RoleProfile("supply-chain-analyst", "Supply Chain Analyst", "operations"),
    RoleProfile("procurement-specialist", "Procurement Specialist", "operations"),
    RoleProfile("logistics-coordinator", "Logistics Coordinator", "operations"),
    RoleProfile("warehouse-manager", "Warehouse Manager", "operations"),
    RoleProfile("store-manager", "Store Manager", "operations"),
    RoleProfile("ecommerce-manager", "Ecommerce Manager", "marketing"),
    RoleProfile("merchandising-analyst", "Merchandising Analyst", "operations"),
    RoleProfile("restaurant-manager", "Restaurant Manager", "operations"),
    RoleProfile("hospitality-manager", "Hospitality Manager", "operations"),
    RoleProfile("event-manager", "Event Manager", "operations"),
    RoleProfile("travel-consultant", "Travel Consultant", "sales"),
    RoleProfile("registered-nurse", "Registered Nurse", "healthcare"),
    RoleProfile("nurse-practitioner", "Nurse Practitioner", "healthcare"),
    RoleProfile("medical-assistant", "Medical Assistant", "healthcare"),
    RoleProfile("clinical-research-coordinator", "Clinical Research Coordinator", "healthcare"),
    RoleProfile("pharmacist", "Pharmacist", "healthcare"),
    RoleProfile("physical-therapist", "Physical Therapist", "healthcare"),
    RoleProfile("occupational-therapist", "Occupational Therapist", "healthcare"),
    RoleProfile("radiology-technologist", "Radiology Technologist", "healthcare"),
    RoleProfile("teacher", "Teacher", "education"),
    RoleProfile("elementary-teacher", "Elementary Teacher", "education"),
    RoleProfile("high-school-teacher", "High School Teacher", "education"),
    RoleProfile("curriculum-specialist", "Curriculum Specialist", "education"),
    RoleProfile("school-counselor", "School Counselor", "education"),
    RoleProfile("legal-assistant", "Legal Assistant", "legal"),
    RoleProfile("paralegal", "Paralegal", "legal"),
    RoleProfile("contract-manager", "Contract Manager", "legal"),
    RoleProfile("attorney", "Attorney", "legal"),
    RoleProfile("privacy-analyst", "Privacy Analyst", "legal"),
    RoleProfile("cybersecurity-analyst", "Cybersecurity Analyst", "security"),
    RoleProfile("security-operations-analyst", "Security Operations Analyst", "security"),
    RoleProfile("identity-and-access-management-analyst", "Identity and Access Management Analyst", "security"),
    RoleProfile("help-desk-analyst", "Help Desk Analyst", "it"),
    RoleProfile("it-support-specialist", "IT Support Specialist", "it"),
    RoleProfile("field-service-engineer", "Field Service Engineer", "it"),
    RoleProfile("mechanical-engineer", "Mechanical Engineer", "operations"),
    RoleProfile("electrical-engineer", "Electrical Engineer", "operations"),
    RoleProfile("civil-engineer", "Civil Engineer", "operations"),
    RoleProfile("industrial-engineer", "Industrial Engineer", "operations"),
    RoleProfile("manufacturing-engineer", "Manufacturing Engineer", "operations"),
    RoleProfile("process-engineer", "Process Engineer", "operations"),
    RoleProfile("environmental-engineer", "Environmental Engineer", "operations"),
    RoleProfile("chemical-engineer", "Chemical Engineer", "operations"),
    RoleProfile("biomedical-engineer", "Biomedical Engineer", "operations"),
]


TOOL_PROFILES: list[ToolProfile] = [
    ToolProfile("ats-resume-checker", "ATS Resume Checker: What It Measures", "ATS resume checker", "what an ATS resume checker actually measures before you apply", ("resume text", "target job description", "section order", "keywords"), ("match score", "missing keywords", "format alerts", "priority fixes"), ("keyword coverage", "section labeling", "evidence density", "readability")),
    ToolProfile("resume-keyword-scanner", "Resume Keyword Scanner Guide", "resume keyword scanner", "how a resume keyword scanner finds relevance gaps", ("resume", "target role", "skills list", "recent bullets"), ("missing terms", "weak synonyms", "placement gaps", "suggested clusters"), ("exact match", "semantic overlap", "role terminology", "recency")),
    ToolProfile("job-description-keyword-extractor", "Job Description Keyword Extractor", "job description keyword extractor", "how to turn a noisy vacancy into a clean keyword list", ("job description", "requirements", "responsibilities", "tool names"), ("priority keywords", "nice-to-have terms", "duplicated phrases", "skill clusters"), ("repetition", "tool specificity", "role-defining nouns", "outcome language")),
    ToolProfile("resume-section-headings-checker", "Resume Section Headings Checker", "resume section headings checker", "which headings parse cleanly and which ones create extraction errors", ("resume headings", "section order", "parser expectations", "layout"), ("safe headings", "risky headings", "mapping fixes", "parser notes"), ("heading clarity", "parser mapping", "sequence", "field extraction")),
    ToolProfile("pdf-vs-docx-checker", "PDF vs DOCX Resume Checker", "PDF vs DOCX resume checker", "when PDF or DOCX is safer for ATS parsing", ("export format", "resume layout", "text layer", "parser target"), ("format recommendation", "text-layer warnings", "layout risk", "parser compatibility"), ("text extraction", "layout complexity", "font encoding", "parser behavior")),
    ToolProfile("bullet-rewrite-assistant", "Resume Bullet Rewrite Assistant", "resume bullet rewrite assistant", "how a rewrite tool turns vague bullets into high-signal ATS evidence", ("weak bullets", "target role", "metrics", "tool context"), ("rewritten bullets", "action verbs", "missing proof", "impact framing"), ("verb strength", "tool specificity", "outcome clarity", "length control")),
    ToolProfile("measurable-impact-bullet-checker", "Measurable Impact Bullet Checker", "measurable impact bullet checker", "how to spot bullets that sound busy but prove nothing", ("experience bullets", "outcomes", "numbers", "scope"), ("metric gaps", "stronger framing", "proof opportunities", "rewrite prompts"), ("metric density", "scope signals", "action verbs", "commercial impact")),
    ToolProfile("skills-gap-scanner", "Resume Skills Gap Scanner", "resume skills gap scanner", "how to compare your resume against missing skill requirements", ("resume skills", "job skills", "related tools", "seniority markers"), ("missing skills", "underused skills", "synonym matches", "placement ideas"), ("coverage", "matching intent", "skill clustering", "role fit")),
    ToolProfile("ats-format-validator", "ATS Resume Format Validator", "ATS resume format validator", "how an ATS format validator checks layout before upload", ("layout", "columns", "tables", "dates"), ("pass/fail formatting alerts", "risk summary", "safe export guidance", "parser notes"), ("layout simplicity", "date consistency", "section order", "contact placement")),
    ToolProfile("resume-summary-optimizer", "Resume Summary Optimizer Guide", "resume summary optimizer", "what makes a summary searchable and recruiter-friendly", ("summary text", "target role", "keywords", "years of experience"), ("summary rewrite", "missing role terms", "weak phrasing alerts", "length guidance"), ("role match", "keyword concentration", "clarity", "brevity")),
    ToolProfile("action-verb-checker", "Resume Action Verb Checker", "resume action verb checker", "how to replace weak verbs that lower resume impact", ("experience bullets", "verb list", "role context", "outcomes"), ("verb replacements", "tone issues", "overused phrasing", "impact suggestions"), ("verb strength", "specificity", "ownership", "result framing")),
    ToolProfile("achievement-metrics-finder", "Achievement Metrics Finder", "achievement metrics finder", "how a metrics finder pulls measurable wins out of ordinary work", ("bullets", "project notes", "results", "baselines"), ("metric prompts", "scope ideas", "before-and-after framing", "evidence suggestions"), ("quantification", "baseline clarity", "scope", "business value")),
    ToolProfile("resume-duplication-checker", "Resume Duplication Checker", "resume duplication checker", "why repeated phrases can make a resume look low-signal", ("resume text", "bullet patterns", "skills", "summary"), ("duplicate phrasing alerts", "rewrite targets", "repetition score", "section overlap"), ("phrase variety", "signal density", "role relevance", "readability")),
    ToolProfile("date-format-normalizer", "Resume Date Format Normalizer", "resume date format normalizer", "how date normalization prevents broken ATS timelines", ("work history dates", "education dates", "gaps", "present markers"), ("normalized date ranges", "risky patterns", "gap notes", "timeline fixes"), ("date clarity", "chronology", "parser stability", "consistency")),
    ToolProfile("keyword-placement-checker", "Keyword Placement Checker for Resumes", "keyword placement checker", "where the same keyword helps most and where it gets ignored", ("summary", "skills", "experience", "projects"), ("placement heatmap", "overuse warnings", "underused sections", "priority edits"), ("section weighting", "repetition quality", "keyword proof", "relevance")),
    ToolProfile("recruiter-scan-preview", "Recruiter Scan Preview for Resumes", "recruiter scan preview", "what a recruiter is likely to notice in the first pass", ("resume hierarchy", "titles", "metrics", "skills"), ("scan summary", "weak first-impression areas", "headline fixes", "proof gaps"), ("visual hierarchy", "role clarity", "achievement density", "time-to-understand")),
    ToolProfile("resume-score-breakdown", "Resume Score Breakdown Guide", "resume score breakdown", "how a resume score should be interpreted section by section", ("resume text", "job description", "score categories", "missing signals"), ("section scores", "weakest areas", "top improvements", "comparison notes"), ("keyword fit", "format risk", "evidence strength", "readability")),
    ToolProfile("resume-benchmark-tool", "Resume Benchmark Tool Explained", "resume benchmark tool", "how benchmark comparisons help prioritize edits", ("resume score", "role average", "seniority", "skill mix"), ("benchmark delta", "improvement priorities", "peer comparisons", "gap summary"), ("market fit", "seniority alignment", "keyword depth", "signal strength")),
    ToolProfile("role-match-heatmap", "Role Match Heatmap Guide", "role match heatmap", "how a heatmap shows which requirements your resume proves well", ("job requirements", "resume bullets", "skills", "projects"), ("matched requirements", "weak coverage zones", "rewrite targets", "summary view"), ("coverage depth", "evidence location", "requirement overlap", "ranking value")),
    ToolProfile("resume-readability-checker", "Resume Readability Checker", "resume readability checker", "how readability affects recruiter speed and ATS interpretation", ("sentence length", "bullets", "headings", "jargon"), ("readability score", "dense sections", "rewrite ideas", "scanability notes"), ("sentence control", "clarity", "section balance", "jargon load")),
    ToolProfile("workday-parser-checker", "Workday Parser Checker", "Workday parser checker", "which resume structures survive Workday parsing best", ("resume file", "dates", "headings", "skills"), ("Workday-specific risks", "safe layout notes", "format suggestions", "field extraction gaps"), ("timeline extraction", "heading mapping", "file stability", "keyword visibility")),
    ToolProfile("greenhouse-parser-checker", "Greenhouse Parser Checker", "Greenhouse parser checker", "how to spot issues before uploading to Greenhouse", ("resume", "summary", "skills", "file format"), ("Greenhouse-specific alerts", "layout notes", "keyword gaps", "export advice"), ("keyword searchability", "layout simplicity", "field accuracy", "resume text quality")),
    ToolProfile("experience-bullet-grader", "Experience Bullet Grader", "experience bullet grader", "how to grade bullets for ATS value and recruiter clarity", ("bullets", "target role", "metrics", "tools"), ("graded bullets", "weak patterns", "rewrite suggestions", "impact score"), ("action verbs", "tool proof", "outcome strength", "brevity")),
    ToolProfile("project-section-optimizer", "Project Section Optimizer", "project section optimizer", "when projects add search value and when they add noise", ("project titles", "stack", "outcomes", "role target"), ("project order", "keyword gaps", "rewrite suggestions", "space guidance"), ("role relevance", "technical specificity", "outcome proof", "duplication control")),
    ToolProfile("skills-cluster-builder", "Resume Skills Cluster Builder", "skills cluster builder", "how to group skills so ATS and recruiters read them faster", ("skill list", "role target", "tools", "seniority"), ("clustered skills", "orphan terms", "missing groups", "ordering recommendations"), ("grouping clarity", "semantic fit", "coverage", "scan speed")),
]


DATASET_PROFILES: list[DatasetProfile] = [
    DatasetProfile("fintech", "Fintech", "engineering", "Engineering", "backend"),
    DatasetProfile("fintech", "Fintech", "data", "Data", "data-engineering"),
    DatasetProfile("fintech", "Fintech", "operations", "Operations", "operations"),
    DatasetProfile("fintech", "Fintech", "marketing", "Marketing", "marketing"),
    DatasetProfile("fintech", "Fintech", "sales", "Sales", "sales"),
    DatasetProfile("healthcare", "Healthcare", "engineering", "Engineering", "backend"),
    DatasetProfile("healthcare", "Healthcare", "data", "Data", "data"),
    DatasetProfile("healthcare", "Healthcare", "operations", "Operations", "operations"),
    DatasetProfile("healthcare", "Healthcare", "marketing", "Marketing", "marketing"),
    DatasetProfile("healthcare", "Healthcare", "sales", "Sales", "sales"),
    DatasetProfile("saas", "SaaS", "engineering", "Engineering", "backend"),
    DatasetProfile("saas", "SaaS", "data", "Data", "data-engineering"),
    DatasetProfile("saas", "SaaS", "operations", "Operations", "operations"),
    DatasetProfile("saas", "SaaS", "marketing", "Marketing", "marketing"),
    DatasetProfile("saas", "SaaS", "sales", "Sales", "sales"),
    DatasetProfile("ecommerce", "Ecommerce", "engineering", "Engineering", "fullstack"),
    DatasetProfile("ecommerce", "Ecommerce", "data", "Data", "data"),
    DatasetProfile("ecommerce", "Ecommerce", "operations", "Operations", "operations"),
    DatasetProfile("ecommerce", "Ecommerce", "marketing", "Marketing", "marketing"),
    DatasetProfile("ecommerce", "Ecommerce", "sales", "Sales", "sales"),
    DatasetProfile("cybersecurity", "Cybersecurity", "engineering", "Engineering", "security"),
    DatasetProfile("cybersecurity", "Cybersecurity", "data", "Data", "data"),
    DatasetProfile("cybersecurity", "Cybersecurity", "operations", "Operations", "operations"),
    DatasetProfile("cybersecurity", "Cybersecurity", "marketing", "Marketing", "marketing"),
    DatasetProfile("cybersecurity", "Cybersecurity", "sales", "Sales", "sales"),
    DatasetProfile("manufacturing", "Manufacturing", "engineering", "Engineering", "operations"),
    DatasetProfile("manufacturing", "Manufacturing", "data", "Data", "data"),
    DatasetProfile("manufacturing", "Manufacturing", "operations", "Operations", "operations"),
    DatasetProfile("manufacturing", "Manufacturing", "marketing", "Marketing", "marketing"),
    DatasetProfile("manufacturing", "Manufacturing", "sales", "Sales", "sales"),
    DatasetProfile("logistics", "Logistics", "engineering", "Engineering", "operations"),
    DatasetProfile("logistics", "Logistics", "data", "Data", "data"),
    DatasetProfile("logistics", "Logistics", "operations", "Operations", "operations"),
    DatasetProfile("logistics", "Logistics", "marketing", "Marketing", "marketing"),
    DatasetProfile("logistics", "Logistics", "sales", "Sales", "sales"),
    DatasetProfile("education", "Education", "engineering", "Engineering", "backend"),
    DatasetProfile("education", "Education", "data", "Data", "data"),
    DatasetProfile("education", "Education", "operations", "Operations", "education"),
    DatasetProfile("education", "Education", "marketing", "Marketing", "marketing"),
    DatasetProfile("education", "Education", "sales", "Sales", "sales"),
    DatasetProfile("climate-tech", "Climate Tech", "engineering", "Engineering", "operations"),
    DatasetProfile("climate-tech", "Climate Tech", "data", "Data", "data-engineering"),
    DatasetProfile("climate-tech", "Climate Tech", "operations", "Operations", "operations"),
    DatasetProfile("climate-tech", "Climate Tech", "marketing", "Marketing", "marketing"),
    DatasetProfile("climate-tech", "Climate Tech", "sales", "Sales", "sales"),
    DatasetProfile("media", "Media", "engineering", "Engineering", "frontend"),
    DatasetProfile("media", "Media", "data", "Data", "data"),
    DatasetProfile("media", "Media", "operations", "Operations", "operations"),
    DatasetProfile("media", "Media", "marketing", "Marketing", "marketing"),
    DatasetProfile("media", "Media", "sales", "Sales", "sales"),
]


OPENERS = (
    "People usually search this topic after an ATS rejects a good resume or a recruiter never reaches the phone screen stage.",
    "Most search intent here comes from applicants who suspect the resume is being parsed incorrectly before anyone reviews the substance.",
    "This query usually appears when the candidate has the right experience but the document is not surfacing that experience cleanly in search or parsing.",
)

INTRO_FOLLOWUPS = (
    "The fix is rarely more effort. It is usually better signal placement, cleaner parsing, and sharper proof.",
    "The highest leverage change is normally structural: give the system clearer titles, cleaner headings, and stronger evidence in the first readable bullets.",
    "What matters is not only whether the keyword exists, but whether the parser can connect it to the right section, date range, and achievement.",
)


def seeded_rng(key: str) -> random.Random:
    seed = int(hashlib.sha1(key.encode("utf-8")).hexdigest()[:12], 16)
    return random.Random(seed)


def humanize_slug(slug: str) -> str:
    return slug.replace("-", " ").title()


def ensure_title(value: str) -> str:
    value = re.sub(r"\s+", " ", value).strip()
    if len(value) <= 60:
        return value
    value = value.replace(" Checklist", "").replace(" Guide", "")
    if len(value) <= 60:
        return value
    return value[:60].rstrip()


def ensure_meta(value: str) -> str:
    value = re.sub(r"\s+", " ", value).strip()
    if len(value) < 140:
        padding = " See examples, common failures, and fixes that improve ATS readability."
        value = (value + padding)[:160].rstrip()
    if len(value) > 160:
        value = value[:160]
        if " " in value:
            value = value.rsplit(" ", 1)[0]
    return value


def word_count(markdown: str) -> int:
    return len(re.findall(r"\b[\w/+-]+\b", markdown))


def insert_before_internal_links(body: str, extra_block: str) -> str:
    marker = "\n## Internal Link Ideas\n"
    if marker in body:
        return body.replace(marker, f"\n{extra_block.strip()}\n\n## Internal Link Ideas\n", 1)
    return body.rstrip() + "\n\n" + extra_block.strip() + "\n"


def ensure_minimum_body_words(page: SeoPage) -> SeoPage:
    if word_count(page.body) >= MIN_BODY_WORDS:
        return page

    extra_block = f"""## Final ATS Submission Checklist

Before you publish a resume built around {page.primary_keyword}, do one last quality pass:

- keep the layout single-column and machine-readable
- use standard headings so the ATS maps each section correctly
- repeat the strongest role keywords inside recent achievement bullets
- keep metrics, dates, and tool names in plain text instead of graphics
- export a clean file that preserves selectable text for recruiter review
"""

    return SeoPage(
        url_path=page.url_path,
        page_type=page.page_type,
        primary_keyword=page.primary_keyword,
        seo_title=page.seo_title,
        meta_description=page.meta_description,
        h1=page.h1,
        body=insert_before_internal_links(page.body, extra_block),
    )


def frontmatter(page: SeoPage) -> str:
    return "\n".join(
        [
            "---",
            f"seo_title: {page.seo_title}",
            f"meta_description: {page.meta_description}",
            f"url_path: {page.url_path}",
            f"page_type: {page.page_type}",
            f"primary_keyword: {page.primary_keyword}",
            "---",
            "",
        ]
    )


def keyword_table_rows(profile: dict[str, object]) -> str:
    skills = profile["core_skills"]
    clusters = profile["keyword_clusters"]
    rows = [
        ("Summary", clusters[0], "Establishes role fit before the recruiter scans details."),
        ("Skills", skills[0], "Improves exact matching when filters use tool or platform names."),
        ("Recent bullet", clusters[1], "Shows that the keyword is supported by real work, not only a list."),
        ("Project or system", skills[1], "Adds context for scope, platform choice, or domain usage."),
        ("Achievement line", clusters[2], "Connects the keyword to measurable impact."),
    ]
    header = "| Resume Zone | High-Signal Term | Why It Helps |\n|---|---|---|"
    return header + "\n" + "\n".join(f"| {a} | {b} | {c} |" for a, b, c in rows)


def pass_fail_table(headers: tuple[str, str], rows: list[tuple[str, str]]) -> str:
    header = f"| {headers[0]} | {headers[1]} |\n|---|---|"
    return header + "\n" + "\n".join(f"| {a} | {b} |" for a, b in rows)


def internal_links_block(links: list[str]) -> str:
    return "\n".join(f"- `{link}`" for link in links[:5])


def parser_internal_links(parser: ParserProfile) -> list[str]:
    return [
        f"/ats/{parser.slug}-resume-format",
        f"/ats/{parser.slug}-keyword-matching",
        "/tools/ats-format-validator",
        "/tools/pdf-vs-docx-checker",
        "/resume-keywords/software-engineer",
    ]


def role_internal_links(role: RoleProfile) -> list[str]:
    related_skill = CATEGORY_PROFILES[role.category]["core_skills"][0].lower().replace(" ", "-")
    return [
        f"/resume-keywords/{role.slug}",
        f"/skills/{related_skill}-{role.slug}-resume-frequency" if any(target.slug == role.slug for target in SKILL_TARGETS) else f"/skills/sql-backend-engineer-resume-frequency",
        "/ats/workday-resume-format",
        "/tools/resume-keyword-scanner",
        f"/datasets/saas-{role.category.replace('_', '-')}-resume-skills" if role.category in {"backend", "frontend", "fullstack", "data-engineering"} else "/datasets/saas-marketing-resume-skills",
    ]


def skill_internal_links(target: SkillTarget) -> list[str]:
    return [
        f"/resume-keywords/{target.slug}",
        "/tools/resume-keyword-scanner",
        "/tools/keyword-placement-checker",
        "/ats/workday-keyword-matching",
        "/ats-comparisons/workday-vs-greenhouse",
    ]


def tool_internal_links(tool: ToolProfile) -> list[str]:
    return [
        f"/tools/{tool.slug}",
        "/tools/ats-resume-checker",
        "/ats/workday-resume-format",
        "/resume-keywords/backend-engineer",
        "/skills/sql-data-analyst-resume-frequency",
    ]


def dataset_internal_links(dataset: DatasetProfile) -> list[str]:
    family_role = {
        "engineering": "software-engineer",
        "data": "data-analyst",
        "operations": "operations-manager",
        "marketing": "marketing-manager",
        "sales": "account-executive",
    }[dataset.family_slug]
    return [
        f"/datasets/{dataset.industry_slug}-{dataset.family_slug}-resume-skills",
        f"/resume-keywords/{family_role}",
        "/tools/resume-benchmark-tool",
        "/tools/skills-gap-scanner",
        "/ats-comparisons/workday-vs-greenhouse",
    ]


def comparison_internal_links(left: ParserProfile, right: ParserProfile) -> list[str]:
    return [
        f"/ats/{left.slug}-resume-format",
        f"/ats/{right.slug}-resume-format",
        f"/ats/{left.slug}-keyword-matching",
        "/tools/ats-format-validator",
        "/tools/recruiter-scan-preview",
    ]


def render_parser_page(parser: ParserProfile, focus: dict[str, str]) -> SeoPage:
    rng = seeded_rng(parser.slug + focus["slug"])
    opener = rng.choice(OPENERS)
    followup = rng.choice(INTRO_FOLLOWUPS)
    parser_issue = parser.weak_points[0]
    parser_strength = parser.strengths[0]
    primary_keyword = focus["primary_pattern"].format(parser=parser.title)
    title = ensure_title(focus["title_pattern"].format(parser=parser.title))
    meta = ensure_meta(
        f"Learn how {parser.title} reads resumes, what recruiters scan first, and which formatting or keyword issues prevent clean ATS parsing."
    )
    h1 = focus["h1_pattern"].format(parser=parser.title)
    rows = [
        ("One-column layout with plain headings", f"Usually passes because {parser.title} can map titles, dates, and skills without guessing."),
        ("Sidebar with dates or skills", f"Often fails because {parser.title} may read the sidebar out of order or detach it from the main role history."),
        ("Standard heading labels", f"Safer because {parser.title} already expects labels such as Experience, Skills, and Education."),
        ("Decorative text boxes", f"Risky because {parser.title} can flatten or skip text in boxed layouts."),
    ]
    body = f"""# {h1}

{opener} {followup} This guide focuses on {parser.title}, a system that tends to reward {parser_strength} and struggle with {parser_issue}. That matters because the recruiter often sees {parser.recruiter_view}, not only the visual design of your original document. If the parser splits dates, misses a skill cluster, or fails to map a heading, a strong candidate can look incomplete in search results.

You will see how {parser.title} typically reads resume structure, where applicants lose keyword visibility, and what adjustments give the parser cleaner evidence. The goal is practical: keep the format simple enough for extraction, but strong enough for recruiter scanning. The examples below show what tends to pass, what tends to break, and why the difference affects ranking inside an ATS workflow.

## What {parser.title} Usually Tries to Extract First

{parser.title} usually performs best when the resume makes four things obvious:

- recent role title
- employer name
- date range
- role-specific skills that are repeated in proof-based bullets

The system reads faster when the resume uses stable section order and plain formatting. In practice, the strongest files make it easy to connect a tool or keyword to a recent project, not just a long skills list.

### Signals that often rank cleanly in {parser.title}

- Direct role titles such as `Backend Engineer` or `Data Analyst`
- Month and year ranges on one line
- Standard headings like `Experience`, `Skills`, and `Education`
- Proof-oriented bullets with tools, scope, and measurable outcomes

## {focus["section_title"].format(parser=parser.title)}

The safest strategy is not to design around aesthetics. It is to design around extraction order. {parser.title} is more reliable when the file keeps important text in the main reading column and avoids layout features that ask the parser to infer relationships.

{pass_fail_table(("Formatting Pattern", "What Happens in " + parser.title), rows)}

### File-format recommendation

For this parser, the safest upload is usually {parser.preferred_format}. If your current PDF uses custom fonts, icons, or exported design software text layers, test a cleaner DOCX or a plain-text PDF export before assuming the content is the problem.

## Keyword Placement That Improves Searchability

{parser.title} does not reward keyword stuffing. It tends to work better when the same important term appears in more than one readable zone:

- a short summary
- a grouped skills block
- one or two recent bullets
- a project or system description when relevant

This is why a keyword such as `PostgreSQL` or `Salesforce` performs better when it is attached to a task and result, not just dropped into a list.

### Weak vs parser-friendly phrasing

{pass_fail_table(("Weak Resume Line", "Stronger Version"), [
    ("Worked on platform improvements.", "Improved platform reliability by tightening alerting and deployment checks."),
    ("Used SQL and dashboards.", "Built SQL reporting and dashboard logic for weekly decision reviews."),
    ("Helped with customer issues.", "Resolved escalated support issues and reduced response delays for priority accounts."),
    ("Managed multiple projects.", "Prioritized cross-team projects and tracked delivery against weekly milestones."),
])}

## Analysis: Where {parser.title} Resumes Usually Lose Signal

Across resume reviews aimed at systems like {parser.title}, the same failures appear repeatedly. The document may contain the right experience, but the parser cannot attach the information to the correct field or section.

- Dates are separated from the employer line, so chronology weakens.
- Skills appear only as badges, charts, or icons, so exact matching drops.
- Headings are creative rather than standard, so mapping becomes inconsistent.
- Bullets use soft verbs with no measurable outcome, so recruiter search still looks thin after parsing.

The stronger pattern is the opposite: one readable column, standard headings, repeated exact terms, and short bullets that prove ownership. That gives the ATS better extraction and gives the recruiter better skim speed.

## Common Mistakes That Hurt {parser.title} Performance

### 1. Putting key information in sidebars

When dates, certifications, or major skills sit in a narrow side panel, {parser.title} may read them out of sequence or skip them entirely.

### 2. Using generic bullets

Bullets like `Responsible for platform support` carry weak ranking value. The parser may capture them, but the recruiter still sees low-signal text with no tool, scope, or result.

### 3. Renaming standard sections

Labels such as `What I Bring` or `Selected Wins` can be readable to humans and still reduce ATS certainty. Safer labels are boring on purpose.

## Best Practices for Clean ATS Parsing and Recruiter Review

- Keep your most recent role title, employer, and dates tightly grouped.
- Repeat high-priority keywords in both Skills and recent bullets.
- Prefer plain bullets over paragraph blocks.
- Use one date format across the entire file.
- If the resume is visually rich, create a second ATS-safe export for applications.
- Review the file as if the recruiter only gets the parsed summary first.

## FAQ

### Can {parser.title} read PDF resumes well?

Usually yes, if the PDF has a clean text layer and simple structure. Complex exports are much riskier than plain PDFs.

### Does {parser.title} reject resumes with columns?

Not automatically, but columns increase the chance that dates, skills, or headings are read out of order.

### What section headings work best for {parser.title}?

Standard labels such as `Experience`, `Skills`, `Education`, and `Projects` are the safest choice.

### Should I repeat keywords more than once?

Yes, but only where they make sense. A strong term should appear in a summary, a skills cluster, and proof-based bullets.

### Is DOCX better than PDF for {parser.title}?

When the PDF export is complex, DOCX is often safer. If the PDF is clean, both can work.

### What hurts {parser.title} parsing most often?

Sidebars, text boxes, split dates, and weak bullets with no measurable result.

## Internal Link Ideas

{internal_links_block(parser_internal_links(parser))}
"""
    return SeoPage(f"/ats/{parser.slug}-{focus['slug']}", focus["page_type"], primary_keyword, title, meta, h1, body)


def render_skill_page(skill: str, target: SkillTarget) -> SeoPage:
    profile = CATEGORY_PROFILES[target.category]
    primary_keyword = f"{skill} skill frequency {target.title.lower()} resume"
    title = ensure_title(f"{skill} Skill Frequency: {target.title} Resumes")
    meta = ensure_meta(
        f"See where {skill} appears on strong {target.title.lower()} resumes, what recruiters expect, and how to place it without ATS keyword stuffing."
    )
    h1 = f"{skill} Skill Frequency on {target.title} Resumes"
    cluster_terms = ", ".join(profile["keyword_clusters"][:3])
    body = f"""# {h1}

When someone searches for {skill} skill frequency on {target.title.lower()} resumes, the real question is not how many times to repeat the term. It is where the skill should appear, what companion terms recruiters expect around it, and how to prove it in a way an ATS can parse. A single skill in the wrong place may do very little. The same skill connected to scope, system context, and a measurable result usually performs much better.

This page shows how {skill} tends to appear on stronger {target.title.lower()} resumes, where it adds ranking value, and where it becomes noise. You will see frequency patterns, supporting keywords, weak versus ATS-optimized phrasing, and the formatting choices that help recruiters scan the skill quickly.

## Where {skill} Usually Shows Up on Stronger Resumes

The strongest {target.title.lower()} resumes usually place {skill} in more than one readable zone, but not in every line. That keeps the signal clear without making the document sound engineered for search.

- Summary or headline when {skill} is central to the target role
- Skills section in the right category grouping
- One or two recent bullets with real context
- Projects section if the tool was used in a concrete build, analysis, or delivery flow

### Placement pattern that tends to work

{keyword_table_rows(profile)}

## Top Skills Recruiters Expect to See Around {skill}

{skill} rarely stands alone in review. Recruiters use it as a clue about adjacent capability. On {target.title.lower()} resumes, the strongest companion terms usually connect {skill} to execution rather than listing it in isolation.

- Core companions: {", ".join(profile["core_skills"][:4])}
- Process or outcome language: {cluster_terms}
- Proof signals: {", ".join(profile["metrics"][:3])}

If {skill} appears without any of those support terms, the resume can look shallow even when the candidate is qualified.

## Weak vs ATS-Optimized Usage of {skill}

{pass_fail_table(("Weak Resume Phrase", "ATS-Optimized Version"), [
    (f"Used {skill} in day-to-day work.", f"Used {skill} in a production workflow and tied it to a measurable result."),
    (f"{skill} listed in skills only.", f"{skill} repeated in Skills and in a recent bullet with system context."),
    (f"Knowledge of {skill}.", f"Applied {skill} to a concrete business or product problem with visible output."),
    (f"Worked with {skill} tools.", f"Named the exact stack, workflow, or deliverable where {skill} drove an outcome."),
])}

### Resume snippet example

Weak:

`Used {skill} and dashboards for reporting.`

Stronger:

`Built reporting workflows with {skill} and adjacent tools; improved stakeholder access to weekly decision data and reduced manual cleanup.`

## Analysis: What the Frequency Pattern Actually Means

High-performing resumes usually show a balanced frequency pattern for {skill}:

- once in the summary if the role depends on it
- once in a grouped skills block
- one to three times in recent evidence-based bullets
- occasionally in a project section if the role is technical or portfolio-heavy

That pattern works because ATS systems can match the term while recruiters can still see why it matters. Overuse creates the opposite effect. If {skill} appears in every bullet with no variation, the document starts to look synthetic. If it appears only once in Skills, the recruiter may not trust that it is current.

## Common Mistakes That Lower the Value of {skill}

### 1. Repeating the skill without proof

If {skill} appears multiple times but never next to scope or results, the term adds little ranking value after the first mention.

### 2. Hiding the skill in dense lists

A long comma-heavy skills paragraph makes exact matching possible but slows recruiter scanning. Grouped skills are easier to interpret.

### 3. Using outdated synonyms only

If the job description uses a specific naming convention, mirror it once. Do not rely only on shorthand if exact matching matters.

### 4. Pairing {skill} with weak verbs

Soft verbs such as `helped`, `assisted`, or `supported` reduce the strength of the signal around the skill.

## Best Practices for Keyword Placement and ATS Readability

- Put {skill} in the summary only if it is central to the role.
- Keep the skills section grouped by function, not one flat list.
- Prove {skill} with one strong recent bullet before adding more mentions.
- Use measurable language so the recruiter sees impact, not tool familiarity alone.
- Keep supporting terms nearby, especially {", ".join(profile["core_skills"][:3])}.
- Review whether the term is current, relevant, and readable in 5 seconds.

## FAQ

### How many times should {skill} appear on a resume?

Usually two to four useful mentions are enough when the role depends on it and the resume includes proof.

### Does ATS count {skill} in the skills section only?

ATS can match it there, but recruiters often trust it more when they also see it in experience bullets.

### Can too many mentions of {skill} hurt a resume?

Yes. Repetition without context can look forced and crowd out stronger evidence.

### Should I use synonyms for {skill}?

Use the exact term from the job post at least once, then add close variants only if they are naturally true.

### What is the best section for {skill}?

Usually a grouped skills block plus one or two recent bullets gives the strongest combination of matchability and proof.

### What if I used {skill} on older projects only?

Keep it if it is relevant, but signal recency honestly and avoid presenting it as your sharpest current strength if that is not true.

## Internal Link Ideas

{internal_links_block(skill_internal_links(target))}
"""
    return SeoPage(f"/skills/{skill.lower().replace(' ', '-')}-{target.slug}-resume-frequency", "skill_frequency_analysis", primary_keyword, title, meta, h1, body)


def render_comparison_page(left: ParserProfile, right: ParserProfile) -> SeoPage:
    primary_keyword = f"{left.title} vs {right.title} ATS comparison"
    title = ensure_title(f"{left.title} vs {right.title} ATS Comparison")
    meta = ensure_meta(
        f"Compare {left.title} and {right.title} resume parsing, keyword matching, and formatting risks so one resume works better across both ATS systems."
    )
    h1 = f"{left.title} vs {right.title} ATS: Resume Parsing Differences"
    body = f"""# {h1}

Applicants usually search this comparison after realizing one resume must survive more than one application system. That is a real problem: a document that reads cleanly in {left.title} can still lose signal in {right.title} if the file format, headings, or date structure are fragile. The goal is not to build two completely different resumes. The goal is to understand which formatting choices are durable across both systems.

This page compares how {left.title} and {right.title} tend to read work history, keywords, and layout. You will see where the two systems behave similarly, where they diverge, and what adjustments create a safer resume for both recruiter search environments.

## What Both ATS Platforms Usually Read Well

{left.title} and {right.title} both respond better to resumes that keep critical information in a plain, readable order:

- reverse chronological experience
- standard section headings
- exact role-relevant keywords
- bullets that connect tool, scope, and result

Both systems also become more reliable when dates and job titles live in the main content column rather than in design-heavy side structures.

## Where {left.title} and {right.title} Differ Most

### {left.title}

- Stronger with: {", ".join(left.strengths[:3])}
- More fragile around: {", ".join(left.weak_points[:3])}
- Safer format: {left.preferred_format}

### {right.title}

- Stronger with: {", ".join(right.strengths[:3])}
- More fragile around: {", ".join(right.weak_points[:3])}
- Safer format: {right.preferred_format}

## Formatting That Passes vs Fails Across Both

{pass_fail_table((f"Safer in {left.title} and {right.title}", "Higher-Risk Pattern"), [
    ("One-column layout with direct titles and dates", "Two-column design with dates or skills detached from the role line"),
    ("Skills grouped by category", "Skill badges or charts with no plain-text backup"),
    ("Month-year dates on one line", "Date fragments split across separate lines or columns"),
    ("Plain bullets with outcomes", "Paragraph blocks with generic duties only"),
])}

## Keyword Matching Differences Recruiters Actually Feel

The practical difference is not whether either ATS can read a keyword at all. It is whether the term stays connected to the right evidence once parsing finishes.

For example:

- In {left.title}, a clean skills block plus recent bullets often gives enough keyword coverage for recruiter search.
- In {right.title}, the same resume can weaken if the file export fragments headings or pushes key terms into a stylized sidebar.

That is why one resume should not only contain the keyword. It should repeat the term in searchable plain text and attach it to a recent accomplishment.

## Analysis: Cross-ATS Failure Patterns

The resumes that struggle most across both systems usually share the same weak traits:

- layout complexity that forces the parser to guess reading order
- exact terms hidden in graphics, icons, or charts
- inconsistent date formatting that breaks chronology
- vague bullets that never prove a keyword with measurable work

The resumes that travel better across both systems normally do three things well:

- they use standard section labels
- they repeat exact role terms in multiple readable zones
- they keep proof close to the keyword

That combination protects both ATS extraction and recruiter skim speed.

## Common Mistakes When Applying Across Multiple ATS Platforms

### 1. Optimizing only for visual design

A resume built for aesthetics can still fail if one system misreads the layout and the recruiter never sees the right extracted profile.

### 2. Depending on one file format blindly

PDF can work well, but if the export has a weak text layer, one of the systems may degrade faster than the other.

### 3. Using creative section labels

Custom headings may be readable to people but less reliable for parser mapping across different ATS platforms.

## Best Practices for One Resume That Works in Both Systems

- Keep the main application resume one-column and plain.
- Use exact skill terms from the job description at least once in plain text.
- Place major tools in Skills and in recent proof-based bullets.
- Keep date ranges and titles tightly connected.
- Test a DOCX fallback when the PDF export is heavily styled.
- Review whether a recruiter could understand your last two roles in under 10 seconds.

## FAQ

### Is one resume enough for both {left.title} and {right.title}?

Usually yes, if the structure is simple and the keyword placement is strong.

### Which format is safer across both platforms?

The safest answer is the cleaner file. For many candidates, that means DOCX or a plain-text PDF with no layout tricks.

### Do both systems struggle with columns?

Yes. Multi-column layouts often create extraction problems across both platforms.

### Should I change section headings for one ATS?

No. Standard headings are the most durable choice across systems.

### What is the biggest cross-platform parsing risk?

Keywords or dates that are visually separated from the role they are meant to support.

### Can recruiters still open the original file?

Often yes, but parsed searchability still matters because it influences whether your profile gets surfaced in the first place.

## Internal Link Ideas

{internal_links_block(comparison_internal_links(left, right))}
"""
    return SeoPage(f"/ats-comparisons/{left.slug}-vs-{right.slug}", "ats_comparison", primary_keyword, title, meta, h1, body)


def render_role_page(role: RoleProfile) -> SeoPage:
    profile = CATEGORY_PROFILES[role.category]
    primary_keyword = f"{role.title} resume keywords"
    title = ensure_title(f"{role.title} Resume Keywords for ATS")
    meta = ensure_meta(
        f"Find the {role.title.lower()} resume keywords recruiters expect, where to place them, and which weak phrases lower ATS match quality."
    )
    h1 = f"{role.title} Resume Keywords That Actually Help"
    body = f"""# {h1}

Most people searching for {role.title.lower()} resume keywords do not need more buzzwords. They need a cleaner way to prove that they already fit the role. ATS systems and recruiters usually scan for two things at the same time: exact terms that map to the vacancy, and evidence that those terms describe real work. If the keyword is present without proof, the resume can still feel thin. If the proof is strong but the terms are missing, the profile can be harder to find.

This page breaks down the keyword clusters that tend to matter most for {role.title.lower()} roles, where those terms belong on the resume, and which phrasing patterns usually improve both ATS readability and recruiter confidence. You will also see common failures, stronger bullet examples, and a practical checklist you can use before applying.

## Which {role.title} Keywords Recruiters Expect to See

Recruiters are rarely looking for one perfect phrase. They are usually scanning for a cluster of related terms that together show role fit. For {role.title.lower()} positions, the highest-signal clusters often revolve around:

- Core tools: {", ".join(profile["core_skills"][:4])}
- Work patterns: {", ".join(profile["keyword_clusters"][:3])}
- Outcome language: {", ".join(profile["metrics"][:3])}

If your resume uses only broad wording such as `worked on`, `supported`, or `helped with`, the system may capture the text but the recruiter still does not get a strong picture of capability.

## Top Skills Recruiters Expect to See

The skill block should not try to hold every tool you have touched. It should support the target role and make the rest of the resume easier to scan.

- High-priority skills for this role: {", ".join(profile["core_skills"])}
- Strong recruiter signals: {profile["recruiter_focus"]}
- Resume sections that usually carry the most weight: {", ".join(profile["top_headings"])}

### Weak vs ATS-Optimized Keywords

{pass_fail_table(("Weak Phrase", "Stronger Phrase"), [
    ("Worked on projects in a fast-paced team.", profile["strong_bullet"]),
    ("Experienced with many business tools.", f"Used {profile['core_skills'][0]} and {profile['core_skills'][1]} in role-specific delivery rather than listing them without context."),
    ("Responsible for process improvements.", f"Improved {profile['metrics'][0]} and {profile['metrics'][1]} with clearer ownership and measurable before-and-after framing."),
    ("Strong communication and teamwork.", f"Coordinated cross-functional delivery and tied stakeholder work to a concrete business result."),
])}

## How ATS Ranking Logic Usually Works for This Role

ATS matching becomes more useful when the same role signal appears in a few strategic places:

- a summary or headline
- a grouped skills block
- the most recent one or two roles
- a project section if it adds missing evidence

That pattern helps because the system can match the term, while the recruiter can verify it quickly. For example, a keyword such as `{profile['core_skills'][0]}` is stronger when it appears in Skills and in a bullet that shows what changed because of it. Stronger resumes do not only name tools. They show what the tool enabled.

## Analysis: Which Keyword Clusters Carry the Most Weight

The strongest {role.title.lower()} resumes usually balance exact terminology with proof. A useful way to think about the content is by cluster, not by isolated word count.

{keyword_table_rows(profile)}

In practice, the resumes that rank better for this role tend to mention one core tool, one work-pattern term, and one measurable outcome in the same recent bullet. That makes the document legible to both search filters and humans.

## Common Mistakes That Hurt ATS Performance

### 1. Long skills lists with no prioritization

If every skill appears at the same level, the recruiter cannot tell what is current or important.

### 2. Keywords with no measurable achievement

ATS may still match the phrase, but recruiter confidence drops if the resume never shows what improved.

### 3. Generic verbs and generic scope

`Helped`, `assisted`, and `worked on` weaken ownership. The reader learns there was activity, but not impact.

### 4. Layout that hides the signal

If important terms live in tables, sidebars, or graphics, the ATS may miss them or map them poorly.

## Best Practices for Keyword Placement and Resume Structure

- Mirror the exact job title once if it matches your real experience.
- Group skills by type so the recruiter can scan them in seconds.
- Put the highest-priority tools into recent bullets, not only Skills.
- Use measurable achievements wherever possible.
- Keep the first screen of the resume dense with role-defining evidence.
- Remove low-value filler so stronger terms stand out.

## FAQ

### How many keywords should a {role.title.lower()} resume contain?

Enough to cover the repeated requirements in the job description, but not so many that the resume stops sounding credible or readable.

### Should keywords go only in the skills section?

No. The strongest keywords should also appear in experience bullets with context and outcomes.

### Can ATS read synonyms for role keywords?

Sometimes, but exact terms are still safer. Use the job-description wording where it is accurate.

### What is the best section for recruiter attention?

The top third of the resume matters most: summary, key skills, and the first recent role.

### Do measurable achievements matter for ATS?

They matter more for recruiters, but they also strengthen the meaning of the matched keyword and improve overall document quality.

### Should I repeat the role title?

Repeat it naturally where it fits. Do not force it into every section.

## Internal Link Ideas

{internal_links_block(role_internal_links(role))}
"""
    return SeoPage(f"/resume-keywords/{role.slug}", "resume_keyword_intelligence", primary_keyword, title, meta, h1, body)


def render_tool_page(tool: ToolProfile) -> SeoPage:
    title = ensure_title(tool.title)
    meta = ensure_meta(
        f"Understand what an {tool.primary_keyword} looks for, which signals matter most, and how to use the output to improve ATS and recruiter results."
    )
    h1 = tool.title.replace(" Guide", "").replace(" Explained", "")
    body = f"""# {h1}

People usually search for an {tool.primary_keyword} after a resume feels too vague, too generic, or too unpredictable in ATS screening. The tool itself is not valuable because it gives a score. It is valuable because it converts messy resume text into a clearer set of decisions. A good output tells you where the signal is weak, where the parser may struggle, and which edits create the biggest ranking improvement before a recruiter ever opens the file.

This page explains what the tool is designed to evaluate, what inputs it needs, how the output should be interpreted, and where candidates often misuse the results. The focus is practical: use the tool to improve structure, keyword placement, and proof quality, not to chase meaningless numbers.

## What This Tool Is Trying to Answer

Core question: {tool.core_question}

To answer that well, the tool normally needs a few stable inputs:

- {tool.inputs[0]}
- {tool.inputs[1]}
- {tool.inputs[2]}
- {tool.inputs[3]}

If those inputs are incomplete, the output can still be directionally useful, but the recommendations become broader and less role-specific.

## What the Output Should Help You Fix

The most useful output is not a single score. It is a short decision list. Good tools usually return:

- {tool.outputs[0]}
- {tool.outputs[1]}
- {tool.outputs[2]}
- {tool.outputs[3]}

That gives the applicant something actionable. Instead of `improve your resume`, the output can say `your section headings are safe, but your current bullets under-prove the keyword coverage in the target role`.

## Scoring Logic That Actually Matters

The strongest tools usually judge resumes through a few major signals:

- {tool.scoring_signals[0]}
- {tool.scoring_signals[1]}
- {tool.scoring_signals[2]}
- {tool.scoring_signals[3]}

Those signals matter because they mirror how ATS systems and recruiters split the evaluation problem. The ATS needs clean terms and structure. The recruiter needs confidence that the terms are attached to real work and real outcomes.

## Example: Weak Output vs Useful Output

{pass_fail_table(("Low-Value Output", "Useful Output"), [
    ("General score with no explanation.", "A section-by-section breakdown with concrete fixes."),
    ("Keyword count only.", "Keyword placement plus proof gaps."),
    ("Formatting warning with no example.", "Formatting warning tied to the exact section that needs revision."),
    ("Generic rewrite advice.", "Rewrite guidance connected to role-specific terminology and measurable outcomes."),
])}

### Resume snippet example

Weak interpretation:

`The tool says the score is 71, so the resume must be fine.`

Useful interpretation:

`The score is decent, but the output shows missing role terms in the summary, weak evidence in recent bullets, and a project section that duplicates the skills list.`

## Analysis: What Stronger Candidates Usually Change After Running This Tool

The most effective edits are usually narrow:

- tighten the headline and summary
- regroup the skills block
- replace two or three generic bullets with measurable ones
- fix a file-format or heading issue before uploading

Candidates often get the biggest gain not from rewriting the whole document, but from improving the first readable screen. That is where both ATS extraction and recruiter attention are most sensitive.

## Common Mistakes When Using This Tool

### 1. Treating the score as the goal

The score is only a shortcut. The real value is the explanation behind it.

### 2. Adding every missing keyword

If the job description is noisy, not every term deserves space. Prioritize repeated requirements and role-defining skills.

### 3. Ignoring format warnings

Candidates often focus on content and forget that the file structure may be hiding strong content from the parser.

### 4. Keeping generic bullets after the tool flags them

When the output points to weak evidence, that usually means the resume is missing clearer ownership or measurable change.

## Best Practices for Using Tool Output Well

- Start with role-defining keywords, not every term in the vacancy.
- Fix format and heading issues before deeper copy edits.
- Prioritize the first one or two recent roles.
- Use the output to sharpen proof, not inflate claims.
- Re-run the tool only after meaningful edits, not after cosmetic changes.
- Read the revised resume as if you were a recruiter scanning for 10 seconds.

## FAQ

### Is an {tool.primary_keyword} accurate enough to trust?

It is useful for prioritization, especially when the output explains the score rather than hiding the logic.

### Should I optimize for the score or the recruiter?

Optimize for recruiter clarity and ATS readability together. A better recruiter-ready resume usually produces the healthier score anyway.

### Can this tool replace human review?

No. It is strongest as a screening layer that highlights risk and opportunity before submission.

### What should I fix first after using the tool?

Start with the top readability or keyword-placement issue that affects the most important role evidence.

### Do these tools help with every job type?

Yes, but the best results come when the tool has enough role context to evaluate your resume against the right expectations.

### Why does the tool flag my skills section even when I have the right experience?

Because the problem may be placement, structure, or proof rather than missing experience itself.

## Internal Link Ideas

{internal_links_block(tool_internal_links(tool))}
"""
    return SeoPage(f"/tools/{tool.slug}", "interactive_seo_tool_explanation", tool.primary_keyword, title, meta, h1, body)


def render_dataset_page(dataset: DatasetProfile) -> SeoPage:
    profile = CATEGORY_PROFILES[dataset.category]
    primary_keyword = f"{dataset.industry_title} {dataset.family_title.lower()} resume skills dataset"
    title = ensure_title(f"Resume Skills Dataset: {dataset.industry_title} {dataset.family_title}")
    meta = ensure_meta(
        f"Explore a {dataset.industry_title.lower()} {dataset.family_title.lower()} resume skills dataset with high-signal keywords, common failures, and recruiter-focused formatting patterns."
    )
    h1 = f"Resume Skills Dataset for {dataset.industry_title} {dataset.family_title} Roles"
    body = f"""# {h1}

This page is for applicants and content teams who want more than a generic keyword list. A resume skills dataset is useful because it shows how skills cluster in real hiring contexts: which terms appear together, which ones signal seniority, and which terms are usually missing on weaker resumes. For {dataset.industry_title.lower()} {dataset.family_title.lower()} roles, that matters because the same broad title can mean very different skill expectations depending on industry language, systems, and recruiter priorities.

The analysis below explains what a {dataset.industry_title.lower()} {dataset.family_title.lower()} resume usually needs to surface, how ATS systems interpret those signals, and where candidates often lose search value. You will see common term clusters, pass/fail formatting patterns, and practical ways to turn the dataset into better resume decisions.

## What This Dataset Is Designed to Show

A useful resume dataset is not just a vocabulary dump. It should answer four questions:

- which skills recur in strong resumes
- which companion terms make those skills believable
- which section placements create the clearest ATS signal
- which phrasing patterns weaken recruiter confidence

For {dataset.industry_title.lower()} {dataset.family_title.lower()} roles, the most durable clusters usually combine:

- tools such as {", ".join(profile["core_skills"][:3])}
- process terms such as {", ".join(profile["keyword_clusters"][:3])}
- outcome language tied to {", ".join(profile["metrics"][:2])}

## Top Skill Clusters in {dataset.industry_title} {dataset.family_title}

### Primary cluster

- {profile["core_skills"][0]}
- {profile["core_skills"][1]}
- {profile["core_skills"][2]}

### Secondary cluster

- {profile["keyword_clusters"][0]}
- {profile["keyword_clusters"][1]}
- {profile["keyword_clusters"][2]}

### Recruiter interpretation

When these terms appear together, recruiters infer {profile["recruiter_focus"]}. When they appear as isolated list items, the dataset becomes much less useful for ranking.

## Most Missing Resume Skills in This Dataset

{pass_fail_table(("Often Missing on Weaker Resumes", "Why It Matters"), [
    (profile["keyword_clusters"][0], "Signals how the candidate actually executes the work, not just the tool list."),
    (profile["keyword_clusters"][1], "Shows process depth and role-specific maturity."),
    (profile["metrics"][0], "Gives recruiters evidence that the work changed something measurable."),
    (profile["core_skills"][0], "Helps ATS systems classify the role more confidently."),
])}

## Analysis: How Stronger Resumes Use the Same Terms Differently

The strongest resumes in a dataset like this tend to do three things:

- they repeat the right terms in the right sections
- they connect skills to system context
- they show outcomes rather than only task ownership

For example, `{profile["core_skills"][0]}` on its own is only a match term. `{profile["core_skills"][0]}` inside a bullet that shows scope and result is a stronger search and recruiter signal. The dataset matters because it highlights which neighboring terms convert a weak mention into a strong one.

### Formatting that helps the dataset work

- grouped skills rather than one long paragraph
- standard headings
- recent bullets with measurable language
- plain text instead of badge clouds or charts

## Common Mistakes Hidden by Generic Resume Advice

### 1. Treating every skill as equally important

Datasets reveal hierarchy. Some terms are foundational, some are supporting, and some are noise unless the job explicitly asks for them.

### 2. Listing tools without domain context

Industry language matters. A generic tool mention can look weak if the recruiter expects domain-specific phrasing.

### 3. Ignoring the relationship between keyword and section

The same skill can help in Skills and still underperform if it never appears in a recent bullet.

### 4. Using visually dense layouts

If the ATS cannot reliably read the section where the dataset terms appear, the candidate loses match value even with the right vocabulary.

## Best Practices for Using Dataset Pages in Resume Optimization

- Start with the top recurring terms, not the longest list.
- Prioritize industry-specific phrases if they are truly part of your background.
- Add proof to the first two or three most valuable terms.
- Keep the skills section grouped and readable.
- Use the dataset to remove weak filler as much as to add missing terms.
- Align wording with the actual vacancy before finalizing the resume.

## FAQ

### What is a resume skills dataset?

It is a structured view of the terms, clusters, and phrasing patterns that appear most often in strong resumes for a specific hiring context.

### How should I use this dataset on my resume?

Use it to prioritize which skills to highlight, which terms need proof, and which low-value phrases can be removed.

### Does ATS care about skill frequency?

Yes, but useful frequency matters more than raw repetition. A few high-quality mentions beat many shallow ones.

### Can this dataset replace the job description?

No. It gives you a strong baseline, but the specific vacancy still decides which terms deserve the most space.

### Why do recruiters care about companion terms?

Because they reveal whether a skill was actually used in role-specific work or simply added to a list.

### What if my background crosses multiple industries?

Use the dataset closest to the role you want next, then keep only the transferable signals that are true for you.

## Internal Link Ideas

{internal_links_block(dataset_internal_links(dataset))}
"""
    return SeoPage(f"/datasets/{dataset.industry_slug}-{dataset.family_slug}-resume-skills", "resume_optimization_dataset", primary_keyword, title, meta, h1, body)


def build_pages() -> list[SeoPage]:
    pages: list[SeoPage] = []

    for parser in PARSER_PROFILES:
        for focus in PARSER_FOCUS:
            pages.append(render_parser_page(parser, focus))

    for skill in SKILLS:
        for target in SKILL_TARGETS:
            pages.append(render_skill_page(skill, target))

    comparison_parsers = PARSER_PROFILES[:15]
    for left, right in list(combinations(comparison_parsers, 2))[:75]:
        pages.append(render_comparison_page(left, right))

    for role in ROLE_PROFILES[:ROLE_PAGE_LIMIT]:
        pages.append(render_role_page(role))

    for tool in TOOL_PROFILES:
        pages.append(render_tool_page(tool))

    for dataset in DATASET_PROFILES:
        pages.append(render_dataset_page(dataset))

    return [ensure_minimum_body_words(page) for page in pages]


def validate_pages(pages: list[SeoPage]) -> None:
    assert len(pages) == 500, f"Expected 500 pages, got {len(pages)}"
    url_paths = set()
    for page in pages:
        assert page.url_path not in url_paths, f"Duplicate url path: {page.url_path}"
        url_paths.add(page.url_path)
        assert len(page.seo_title) <= 60, f"Title too long: {page.seo_title}"
        assert 140 <= len(page.meta_description) <= 160, f"Meta length invalid: {page.url_path}"
        words = word_count(page.body)
        assert 800 <= words <= 1400, f"Word count invalid for {page.url_path}: {words}"
        assert page.body.startswith("# "), f"Body missing H1: {page.url_path}"


def write_pages(pages: list[SeoPage]) -> None:
    if CONTENT_ROOT.exists():
        for path in sorted(CONTENT_ROOT.rglob("*.md"), reverse=True):
            path.unlink()
    CONTENT_ROOT.mkdir(parents=True, exist_ok=True)

    manifest: list[dict[str, object]] = []

    for page in pages:
        page.output_path.parent.mkdir(parents=True, exist_ok=True)
        content = frontmatter(page) + page.body.strip() + "\n"
        page.output_path.write_text(content, encoding="utf-8")
        manifest.append(
            {
                "url_path": page.url_path,
                "page_type": page.page_type,
                "primary_keyword": page.primary_keyword,
                "seo_title": page.seo_title,
                "meta_description": page.meta_description,
                "word_count": word_count(page.body),
                "file_path": str(page.output_path.relative_to(ROOT)),
            }
        )

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def main() -> None:
    pages = build_pages()
    validate_pages(pages)
    write_pages(pages)
    print(f"Generated {len(pages)} SEO pages in {CONTENT_ROOT}")


if __name__ == "__main__":
    main()
