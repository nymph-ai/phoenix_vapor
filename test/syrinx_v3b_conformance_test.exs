defmodule PhoenixVapor.SyrinxV3bConformanceTest do
  use ExUnit.Case, async: true

  alias PhoenixVapor.Hybrid.{Classifier, ClientCodegen}

  @fixture Path.expand("fixtures/TimeTravelTable.vue", __DIR__)
  @manifest Path.expand("fixtures/TimeTravelTable.conformance.json", __DIR__)
  @source_sha256 "f93c37898853f1c44584daa672cb97859db42ddf908bb52d00b1925f0295897a"

  test "the canonical TimeTravelTable SFC compiles through the PhoenixVapor Vize backend" do
    source = File.read!(@fixture)
    manifest = @manifest |> File.read!() |> Jason.decode!()
    assert sha256(source) == @source_sha256
    assert manifest["sourceSha256"] == @source_sha256

    descriptor = Vize.parse_sfc!(source)
    script = descriptor.script_setup.content
    template = String.trim(descriptor.template.content)

    {refs, computeds, functions, function_bodies, props} =
      PhoenixVapor.ScriptSetup.parse(script)

    classification =
      Classifier.classify(refs, computeds, functions, function_bodies, props)

    split = Vize.vapor_split!(template)
    {:ok, client_js} = ClientCodegen.generate(source, classification)

    assert length(split.statics) > 0
    assert length(split.slots) > 0
    assert classification.bindings["hovered"] == {:client_ref, "null"}
    assert classification.bindings["rootClass"] == :client_computed
    assert {:ok, _program} = OXC.parse(client_js, "TimeTravelTable.hybrid.js")
    phoenix = manifest["backends"]["phoenixVapor"]
    assert byte_size(client_js) == phoenix["clientJsBytes"]
    assert sha256(client_js) == phoenix["clientJsSha256"]
  end

  defp sha256(contents) do
    :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
  end
end
