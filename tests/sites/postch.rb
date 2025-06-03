require "test/unit"
require_relative "../../lib/sites/postch"

class PostCHTests < Test::Unit::TestCase
  def test_messages
    p = PostCH.new(track_id: 'whatev')
    [
      ["LETTER.*.90.620", "Consignment recorded by the foreign sender (data delivered)"],
      ["LETTER.*.90.913", "Arrival at the processing/collection point"],
      ["LETTER.*.90.942", "Dédouanement à l’exportation"],
      ["LETTER.*.90.944", "held at customs"],
      ["LETTER.*.90.912", "Time at which your consignment was mailed"],
      ["LETTER.*.90.915", "The consignment has left the border point"],
      ["LETTER.*.90.947", "Completion of export customs clearance"],
      ["LETTER.*.90.818", "Arrival in destination country"],
      ["LETTER.*.90.803", "Customs clearance process underway"],
      ["LETTER.*.90.819", "Customs clearance process underway"],
      ["LETTER.*.90.804", "Completion of customs clearance process"],
      ["LETTER.*.90.820", "Sorting - forwarding"],
      ["LETTER.*.90.1001", "Arrival at the collection/delivery point"],
      ["LETTER.*.90.4000", "Delivered"]
    ].each do |t|
      code, expected_msg = t
      assert_equal p.code_to_message(code), expected_msg
    end
  end
end
