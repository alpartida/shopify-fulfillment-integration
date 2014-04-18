require './base'
require 'attr_encrypted'
require 'active_fulfillment'

class FulfillmentService < ActiveRecord::Base
  belongs_to :shop
  attr_encrypted :username, :key => ShopifyApp::SECRET, :attribute => 'username_encrypted'
  attr_encrypted :password, :key => ShopifyApp::SECRET, :attribute => 'password_encrypted'
  validates_presence_of :username, :password
  validates :shop, uniqueness: true
  before_save :check_credentials

  def self.service_name
    @name ||= YAML.load(File.read("config/fulfillment_service.yml"))["service"]["name"]
  end

  def fulfill(order, fulfillment)
    response = instance.fulfill(
      order.id,
      address(order.shipping_address),
      line_items(order, fulfillment),
      fulfill_options(order, fulfillment)
    )

    response.success?
  end

  def fetch_stock_levels(options={})
    instance.fetch_stock_levels(options)
  end

  def fetch_tracking_numbers(order_ids)
    instance.fetch_tracking_numbers(order_ids)
  end

  private

  def instance
    @instance = ActiveMerchant::Fulfillment::ShipwireService.new(
      :login => username,
      :password => password,
      :test => true
    )
  end

   def address(address_object)
    {:name     => address_object.name,
     :company  => address_object.company,
     :address1 => address_object.address1,
     :address2 => address_object.address2,
     :phone    => address_object.phone,
     :city     => address_object.city,
     :state    => address_object.province_code,
     :country  => address_object.country_code,
     :zip      => address_object.zip}
  end

  def line_items(order, fulfillment)
    fulfillment.line_items.map do |line|
      { sku: line.sku,
        quantity: line.quantity,
        description: line.title,
        value: line.price,
        currency_code: order.currency
      } if line.quantity > 0
    end.compact
  end

  def fulfill_options(order, fulfillment)
    {:order_date      => order.created_at,
     :comment         => 'Thank you for your purchase',
     :email           => order.email,
     :tracking_number => fulfillment.tracking_number,
     :warehouse       => '00',
     :shipping_method => "1D", # order.shipping_lines.first.code
     :note            => order.note}
  end

  def check_credentials
    unless instance.valid_credentials?
      errors.add(:password, "Must have valid shipwire credentials to use the services provided by this app.")
      return false
    end
  end

end
