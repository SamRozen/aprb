# https://github.com/artsy/exchange/blob/master/app/events/order_event.rb#L1

defmodule Aprb.Views.CommerceSlackView do
  import Aprb.ViewHelper

  def render(event, routing_key) do
    case routing_key do
      "transaction.created" -> failed_transaction_event(event)
      _ -> order_event(event)
    end
  end

  defp failed_transaction_event(event) do
    %{
      text: ":alert: Failed Transaction",
      attachments: [%{
        fields: [
          %{
            title: "Failure Code",
            value: event["properties"]["failure_code"],
            short: true
          },
          %{
            title: "Failure Message",
            value: event["properties"]["failure_message"],
            short: true
          },
          %{
            title: "Transaction Type",
            value: event["properties"]["transaction_type"],
            short: true
          },
        ] ,
        "actions": [
          %{
            "type": "button",
            "text": "Admin Link",
            "url": exchange_admin_link(event["properties"]["order"]["id"])
          }
        ]
      }],
      unfurl_links: true
    }
  end

  defp order_event(event) do
    title = case event["verb"] do
      "submitted" -> "🤞 Submitted"
      "approved" -> ":yes: Approved"
      "canceled" ->
        case event["properties"]["state_reason"] do
          "seller_lapsed" -> ":hourglass: Seller Lapsed"
          "seller_rejected" -> ":soshocked: Rejected"
        end
      "refunded" -> ":sad-parrot: Refunded"
      "fulfilled" -> " :shipitmoveit: Fulfilled"
      "pending_approval" -> ":hourglass: Approval"
      "pending_fulfillment" -> ":hourglass: :ship:"
      _ -> nil
    end

    case title do
      nil -> nil
      title ->
        %{
          text: "#{title} #{artworks_links_from_line_items(event["properties"]["line_items"])}",
          attachments: order_attachments(event),
          unfurl_links: true
        }
    end
  end

  defp order_attachments(event) do
    seller = fetch_info(event["properties"]["seller_id"], event["properties"]["seller_type"])
    buyer = fetch_info(event["properties"]["buyer_id"], event["properties"]["buyer_type"])
    fields =
      case seller["admin"] do
        nil -> order_attachment_fields(event, buyer, seller)
        admin -> order_attachment_fields(event, buyer, seller) ++ [%{ title: "Admin", value: admin["name"], short: true}]
      end
    [%{
      fields: fields,
      "actions": [
        %{
          "type": "button",
          "text": "Admin Link",
          "url": exchange_admin_link(event["object"]["id"])
        }
      ]
    }]
  end

  defp order_attachment_fields(event, buyer, seller) do
    [
      %{
        title: "Code",
        value: event["properties"]["code"],
        short: true
      },
      %{
        title: "Total Amount",
        value: format_price(event["properties"]["items_total_cents"] / 100),
        short: true
      },
      %{
        title: "Buyer",
        value: cleanup_name(buyer["name"]),
        short: true
      },
      %{
        title: "Seller",
        value: seller["name"],
        short: true
      },
      %{
        title: "Artworks",
        value: artworks_links_from_line_items(event["properties"]["line_items"]),
        short: false
      },
    ]
  end

  defp fetch_info(id, type) do
    case type do
      "user" -> Gravity.get!("/users/#{id}").body
      _ -> Gravity.get!("/v1/partner/#{id}").body
    end
  end

  defp artworks_links_from_line_items(line_items) do
    line_items
      |> Enum.map(fn(li) -> artwork_link(li["artwork_id"]) end)
      |> Enum.map(fn(artwork_link) -> "<#{artwork_link} | >" end)
  end
end
