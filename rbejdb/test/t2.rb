require "rbejdb"
require 'test/unit'

$now = Time.now
$jb = EJDB.open("tdbt2", EJDB::JBOWRITER | EJDB::JBOCREAT | EJDB::JBOTRUNC)


class EJDBTestUnit < Test::Unit::TestCase

  def test_ejdb1_save_load
    assert $jb.is_open?

    parrot1 = {
        "name" => "Grenny",
        "type" => "African Grey",
        "male" => true,
        "age" => 1,
        "birthdate" => $now,
        "likes" => ["green color", "night", "toys"],
        "extra1" => nil
    }
    parrot2 = {
        "name" => "Bounty",
        "type" => "Cockatoo",
        "male" => false,
        "age" => 15,
        "birthdate" => $now,
        "likes" => ["sugar cane"],
        "extra1" => nil
    }

    oids = $jb.save("parrots", parrot1, nil, parrot2)
    assert_not_nil oids
    assert_equal(3, oids.length)
    assert_equal(parrot1["_id"], oids[0])
    assert_nil oids[1]
    assert_equal(parrot2["_id"], oids[2])

    obj = $jb.load("parrots", parrot2["_id"])
    assert_not_nil obj
    assert_equal(parrot2["_id"], obj["_id"])
    assert_equal("Bounty", obj["name"])

    assert EJDB.check_valid_oid_string(parrot2["_id"])
    assert !EJDB.check_valid_oid_string("ololo")

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb2_query1
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.find("parrots", {})

    assert_not_nil results

    assert_equal(2, results.to_a.length)
    assert_equal(2, results.to_a.length) #checking second call gets same result

    results.each { |rv|
      assert rv
      assert rv["_id"].is_a? String
      assert rv["name"].is_a? String
      assert rv["age"].is_a? Numeric
      assert rv["birthdate"] != nil && rv["birthdate"].is_a?(Object)
      assert rv["male"] == true || rv["male"] == false
      assert_nil rv["extra1"]
      assert rv["likes"] != nil && rv["likes"].is_a?(Array)
      assert rv["likes"].length > 0
    }

    results = $jb.find("parrots", {})
    assert_not_nil results
    assert_equal(2, results.to_a.length)


    #count mode
    count = $jb.find("parrots", {}, :onlycount => true)
    assert count.is_a? Numeric
    assert_equal(2, count)

    #findOne
    obj = $jb.find_one("parrots")
    assert_not_nil obj
    assert obj["name"].is_a? String
    assert obj["age"].is_a? Numeric

    #empty query
    results = $jb.find("parrots")
    assert_not_nil results
    assert_equal(2, results.to_a.length)

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb3_query2
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.find("parrots", {:name => /(grenny|bounty)/i}, {:orderby => {:name => 1}})

    assert_not_nil results
    assert_equal(2, results.to_a.length)

    results.each_with_index { |rv, index|
      if index == 0
        assert_equal("Bounty", rv["name"])
        assert_equal("Cockatoo", rv["type"])
        assert_equal(false, rv["male"])
        assert_equal(15, rv["age"])
        assert_equal($now.inspect, rv["birthdate"].inspect)
        assert_equal("sugar cane", rv["likes"].join(","))
      end
    }

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb4_query3
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.find("parrots", {}, [{:name => "Grenny"}, {:name => "Bounty"}], {:orderby => {:name => 1}})

    assert_not_nil results
    assert_equal(2, results.to_a.length)

    results.each_with_index { |rv, index|
      if index == 1
        assert_equal("Grenny", rv["name"])
        assert_equal("African Grey", rv["type"])
        assert_equal(true, rv["male"])
        assert_equal(1, rv["age"])
        assert_equal($now.inspect, rv["birthdate"].inspect)
        assert_equal("green color,night,toys", rv["likes"].join(","))
      end
    }

    assert_equal(2, results.to_a.length)

    # testing force close
    results.close

    assert_raise(RuntimeError) {
      results.to_a.length
    }

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb5_circular
    assert_not_nil $jb
    assert $jb.is_open?

    #Circular query object
    cir_query = {}
    cir_query["cq"] = cir_query

    err = nil
    begin
      $jb.find("parrots", cir_query)
    rescue Exception => e
      err = e
    end

    assert_not_nil err
    assert_equal(err.message, "Converting circular structure to BSON")

    err = nil
    begin
      $jb.find("parrots", {:q => [cir_query]})
    rescue Exception => e
      err = e
    end

    assert_not_nil err
    assert_equal(err.message, "Converting circular structure to BSON")


    cir_array = []
    cir_array[0] = cir_array

    err = nil
    begin
      $jb.find("parrots", {:q => cir_array})
    rescue Exception => e
      err = e
    end

    assert_not_nil err
    assert_equal(err.message, "Converting circular structure to BSON")

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb6_save_load_buffer
    assert_not_nil $jb
    assert $jb.is_open?

    sally = {
        "name" => "Sally",
        "mood" => "Angry",
        "secret" => EJDBBinary.new("Some binary secrect".encode("utf-8").bytes.to_a)
    }

    molly = {
        "name" => "Molly",
        "mood" => "Very angry",
        "secret" => nil
    }

    sally_oid = $jb.save("birds", sally)

    assert_not_nil sally_oid
    assert_not_nil sally["_id"]

    obj = $jb.load("birds", sally_oid)

    assert(obj["secret"].is_a? EJDBBinary)
    assert_equal("Some binary secrect", obj["secret"].to_a.pack("U*"))

    oids = $jb.save("birds", sally, molly)

    assert_not_nil oids
    assert_not_nil oids.find { |oid|
      oid == sally_oid
    }

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb7_use_string_index
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.find("birds", {"name" => "Molly"}, {:explain => true})
    assert_not_nil results
    assert_equal(1, results.to_a.length)

    log = results.log

    assert_not_nil log
    assert log.include? "RUN FULLSCAN"

    #Now set the name string index
    $jb.ensure_string_index("birds", "name")

    results = $jb.find("birds", {"name" => "Molly"}, {:explain => true})
    assert results.log.include? "MAIN IDX: 'sname"

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdb8_cmeta
    assert_not_nil $jb
    assert $jb.is_open?

    dm = $jb.get_db_meta
    assert dm
    assert_equal("tdbt2", dm["file"])
    assert_not_nil dm["collections"]
    assert dm["collections"].is_a? Array

    parrots = dm["collections"][0]
    assert_not_nil parrots
    assert_equal("parrots", parrots["name"])

    puts __method__.inspect + " has passed successfull"
  end

  def test_ejdb9_test_update1
    assert_not_nil $jb
    assert $jb.is_open?

    result = $jb.update("parrots", {"name" => {"$icase" => "GRENNY"}, "$inc" => {"age" => 10}}, {:explain => true})
    assert_equal(1, result.count)

    log = result.log
    assert_not_nil log
    assert log.include?("UPDATING MODE: YES")

    obj = $jb.find_one("parrots", {"age" => 11})
    assert_not_nil obj
    assert_equal("Grenny", obj["name"])

    id = $jb.save("parrots", {"_id" => obj["_id"], "extra1" => 1}, true)
    assert_not_nil id

    obj = $jb.load("parrots", id)
    assert_not_nil obj
    assert_equal("Grenny", obj["name"])
    assert_equal(1, obj["extra1"])

    q = {"_id" => {"$in" => [id]}, "$set" => {"stime" => Time.now}}
    result = $jb.update("parrots", q)
    assert_equal(1, result.count)

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdba_id_nin
    assert_not_nil $jb
    assert $jb.is_open?

    obj = $jb.find_one("parrots", {})
    assert_not_nil obj

    results = $jb.find("parrots", {"_id" => {"$in" => [obj["_id"]]}})

    assert_equal(1, results.count)
    assert_equal(obj["_id"], results.find { true }["_id"])

    results = $jb.find("parrots", {"_id" => {"$nin" => [obj["_id"]]}}, {:explain => true})
    assert results.count > 0

    results.each { |other|
      assert other["_id"]
      assert other["_id"] != obj["_id"]
    }
    assert results.log.include? "RUN FULLSCAN"
    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbb_test_remove
    assert_not_nil $jb
    assert $jb.is_open?

    obj = $jb.find_one("birds", {"name" => "Molly"})
    assert_not_nil obj
    assert_not_nil obj["_id"]
    assert_equal("Very angry", obj["mood"])

    #Bye bye Molly!
    $jb.remove("birds", obj["_id"])

    obj = $jb.find_one("birds", {"name" => "Molly"})
    assert_nil obj

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbc_sync
    assert_not_nil $jb
    assert $jb.is_open?
    $jb.sync
    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbd_remove_colls
    assert_not_nil $jb
    assert $jb.is_open?

    $jb.drop_collection("birds")

    results = $jb.find("birds", {})
    assert_equal(0, results.count)
    assert_nil results.find { true }

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbe_tx1
    assert_not_nil $jb
    assert $jb.is_open?

    obj = {:foo => "bar"}

    assert_equal(false, $jb.get_transaction_status("bars"))

    $jb.begin_transaction("bars")

    $jb.save("bars", obj)
    id = obj["_id"]
    assert_not_nil id

    obj = $jb.load("bars", obj["_id"])
    assert_not_nil obj
    assert $jb.get_transaction_status("bars")

    $jb.rollback_transaction("bars")
    assert_equal(false, $jb.get_transaction_status("bars"))

    obj = $jb.load("bars", obj["_id"])
    assert_nil obj

    $jb.begin_transaction("bars")

    assert $jb.get_transaction_status("bars")
    assert_nil $jb.load("bars", id)
    obj = {:foo => "bar"}

    $jb.save("bars", obj)
    id = obj["_id"]
    assert_not_nil id

    assert_not_nil $jb.load("bars", id)

    $jb.commit_transaction("bars")

    assert_equal(false, $jb.get_transaction_status("bars"))

    assert_not_nil $jb.load("bars", id)

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbf_create_collection_on_upsert
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.update("upsertcoll", {:foo => "bar", "$upsert" => {:foo => "bar"}})
    assert_equal(1, results.count)

    obj = $jb.find_one("upsertcoll", {:foo => "bar"})
    assert_equal("bar", obj["foo"])

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbg_max_and_skip_hints
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.find("parrots", {})
    assert_not_equal(1, results.count)

    results = $jb.find("parrots", {}, {:max => 1})
    assert_equal(1, results.count)

    results = $jb.find("parrots", {}, {:skip => 1})
    assert_equal(1, results.count)

    results = $jb.find("parrots", {}, {:skip => 2})
    assert_equal(0, results.count)

    puts __method__.inspect + " has passed successfull"
  end


  def test_ejdbh_different_hacks
    assert_nil $jb.load("monsters", "111")
    assert_nil $jb.load("parrots", "111")
    assert_nil $jb.load("parrots", "")

    assert_raise(ArgumentError) {
      $jb.load
    }
    assert_raise(ArgumentError) {
      $jb.load("parrots")
    }
    assert_raise(TypeError) {
      $jb.load("parrots", :what_is_this?)
    }
    assert_raise(ArgumentError) {
      $jb.load("parrots", "", "sldslk")
    }


    assert_raise(ArgumentError) {
      $jb.save
    }
    assert_raise(TypeError) {
      $jb.save({})
    }
    $jb.save("monsters")
    assert_raise(RuntimeError) {
      $jb.save("monsters", :monster) #Cannot convert object to bson
    }

    $jb.save("monsters", {})
    assert_raise(RuntimeError) {
      $jb.save("@&^3872638126//d\n", {})
    }

    oid = $jb.save("monsters", {:name => :abracadabra})
    $jb.load("monsters", oid)

    $jb.save("monsters", {:name => :abracadabra}, true)

    assert_raise(RuntimeError) {
      $jb.save("monsters", :what_is_this?)
    }
    assert_raise(RuntimeError) {
      $jb.save("monsters", [{:name => :abracadabra}])
    }

    $jb.save("monsters", nil)
    $jb.save("monsters", {:name => :abracadabra}, {:name => :chupacabra})
    $jb.save("monsters", self)

    #puts $jb.find("monsters").to_a.to_s
    assert_equal(6, $jb.find("monsters").count)


    assert_raise(ArgumentError) {
      $jb.find
    }

    assert_equal(0, $jb.find("dsldajsdlkjasl").count)

    puts __method__.inspect + " has passed successfull"
  end

  def test_ejdbi_close
    assert_not_nil $jb
    assert $jb.is_open?

    results = $jb.find("parrots", {})
    assert_not_nil results
    results.close

    assert_raise(RuntimeError) {
      results.to_a
    }

    $jb.close

    assert !$jb.is_open?
    puts __method__.inspect + " has passed successfull"
  end

end
