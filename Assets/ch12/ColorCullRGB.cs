using UnityEngine;
using System.Collections;

public class ColorCullRGB : PostEffectsBase {

    public Shader ColorCullRGBShader;
    private Material ColorCullRGBMaterial;
    public Material material {
        get {
            ColorCullRGBMaterial = CheckShaderAndCreateMaterial(ColorCullRGBShader, ColorCullRGBMaterial);
            return ColorCullRGBMaterial;
        }
    }

    [Range(0, 1)]
    public int on = 1;

    [Range(0, 255)]
    public int R = 0;

    [Range(0, 255)]
    public int G = 0;

    [Range(0, 255)]
    public int B = 0;

	[Range(0.0f, 1.0f)]
	public float reserve = 1.0f;

    void OnRenderImage(RenderTexture src, RenderTexture dest) {
        if (material != null && on == 1) {
			material.SetFloat("_R", R);
			material.SetFloat("_G", G);
			material.SetFloat("_B", B);
			material.SetFloat("_Reserve", reserve);

            Graphics.Blit(src, dest, material);
        } else {
            Graphics.Blit(src, dest);
        }
    }
}