module StructuredDataHelper
  def jsonld_tag(data)
    tag.script(raw(data.to_json), type: "application/ld+json")
  end

  def organization_jsonld
    {
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Hack Club",
      "url" => "https://hackclub.com",
      "logo" => image_url("og.jpg"),
      "sameAs" => [
        "https://github.com/hackclub",
        "https://twitter.com/hackclub",
        "https://www.youtube.com/@HackClubHQ"
      ]
    }
  end

  def website_jsonld
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "Hack Club Blueprint",
      "url" => "https://blueprint.hackclub.com",
      "description" => "Learn and build cool hardware projects and get funding to make them real!",
      "publisher" => {
        "@type" => "Organization",
        "name" => "Hack Club"
      }
    }
  end

  def faq_jsonld(faq_items)
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => faq_items.map do |item|
        {
          "@type" => "Question",
          "name" => item[:question],
          "acceptedAnswer" => {
            "@type" => "Answer",
            "text" => item[:answer]
          }
        }
      end
    }
  end

  def project_article_jsonld(project)
    data = {
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => project.title,
      "description" => project.description,
      "datePublished" => project.created_at.iso8601,
      "dateModified" => project.updated_at.iso8601,
      "author" => {
        "@type" => "Person",
        "name" => project.user.display_name,
        "url" => user_url(project.user)
      },
      "publisher" => {
        "@type" => "Organization",
        "name" => "Hack Club Blueprint",
        "logo" => {
          "@type" => "ImageObject",
          "url" => image_url("og.jpg")
        }
      },
      "mainEntityOfPage" => {
        "@type" => "WebPage",
        "@id" => project_url(project)
      }
    }
    data["image"] = url_for(project.display_banner) if project.display_banner.attached?
    data
  end

  def breadcrumb_jsonld(items)
    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items.each_with_index.map do |item, i|
        {
          "@type" => "ListItem",
          "position" => i + 1,
          "name" => item[:name],
          "item" => item[:url]
        }
      end
    }
  end
end
