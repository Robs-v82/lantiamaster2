require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "visiting the index" do
    visit users_url
    assert_selector "h1", text: "Users"
  end

  test "creating a User" do
    visit users_url
    click_on "New User"

    fill_in "Firstname", with: @user.firstname
    fill_in "Lastname1", with: @user.lastname1
    fill_in "Lastname2", with: @user.lastname2
    fill_in "Mail", with: @user.mail
    fill_in "Mobile phone", with: @user.mobile_phone
    fill_in "Other phone", with: @user.other_phone
    click_on "Create User"

    assert_text "User was successfully created"
    click_on "Back"
  end

  test "updating a User" do
    visit users_url
    click_on "Edit", match: :first

    fill_in "Firstname", with: @user.firstname
    fill_in "Lastname1", with: @user.lastname1
    fill_in "Lastname2", with: @user.lastname2
    fill_in "Mail", with: @user.mail
    fill_in "Mobile phone", with: @user.mobile_phone
    fill_in "Other phone", with: @user.other_phone
    click_on "Update User"

    assert_text "User was successfully updated"
    click_on "Back"
  end

  test "destroying a User" do
    visit users_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "User was successfully destroyed"
  end
end
