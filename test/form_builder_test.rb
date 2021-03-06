require 'test_helper'

class FormBuilderCompatTest < BaseTest
  let (:form_class) {
    Class.new(Reform::Form) do
      include Reform::Form::ActiveModel::FormBuilderMethods

      property :artist do
        property :name
        validates :name, :presence => true
      end

      collection :songs do
        property :title
        property :release_date
        validates :title, :presence => true
      end

      class LabelForm < Reform::Form
        property :name
      end

      property :label, :form => LabelForm

      property :band do
        property :label do
          property :name
        end
      end
    end
  }

  let (:song) { OpenStruct.new }
  let (:form) { form_class.new(OpenStruct.new(
    :artist => Artist.new(:name => "Propagandhi"),
    :songs  => [song],
    :label  => OpenStruct.new,

    :band => Band.new(Label.new)
    )) }

  it "respects _attributes params hash" do
    form.validate("artist_attributes" => {"name" => "Blink 182"},
      "songs_attributes" => {"0" => {"title" => "Damnit"}},
      "band_attributes"  => {"label_attributes" => {"name" => "Epitaph"}})

    form.artist.name.must_equal "Blink 182"
    form.songs.first.title.must_equal "Damnit"
    form.band.label.name.must_equal "Epitaph"
  end

  it "allows nested collection and property to be missing" do
    form.validate({})

    form.artist.name.must_equal "Propagandhi"

    form.songs.size.must_equal 1
    form.songs[0].model.must_equal song # this is a weird test.
  end

  it "defines _attributes= setter so Rails' FB works properly" do
    form.must_respond_to("artist_attributes=")
    form.must_respond_to("songs_attributes=")
    form.must_respond_to("label_attributes=")
  end

  describe "deconstructed date parameters" do
    let(:form_attributes) do
      {
        "artist_attributes" => {"name" => "Blink 182"},
        "songs_attributes" => {"0" => {"title" => "Damnit", "release_date(1i)" => release_year,
          "release_date(2i)" => release_month, "release_date(3i)" => release_day}}
      }
    end
    let(:release_year) { "1997" }
    let(:release_month) { "9" }
    let(:release_day) { "27" }

    describe "with valid parameters" do
      it "creates a date" do
        form.validate(form_attributes)

        form.songs.first.release_date.must_equal Date.new(1997, 9, 27)
      end
    end

    %w(year month day).each do |date_attr|
      describe "when the #{date_attr} is missing" do
        let(:"release_#{date_attr}") { "" }

        it "rejects the date" do
          form.validate(form_attributes)

          form.songs.first.release_date.must_be_nil
        end
      end
    end
  end

  it "returns flat errors hash" do
    form.validate("artist_attributes" => {"name" => ""},
      "songs_attributes" => {"0" => {"title" => ""}})
    form.errors.messages.must_equal(:"artist.name" => ["can't be blank"], :"songs.title" => ["can't be blank"])
  end
end