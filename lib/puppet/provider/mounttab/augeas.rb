# Alternative Augeas-based provider for mounttab, distributed in
# puppetlabs-mount_providers.
#
# This is a wrapper around different implementations, which lives in the
# AugeasProviders namespace.  The idea is to use a single provider called
# "augeas" so site-wide defaults can be set rather than forcing the user to
# set the provider based on OS upfront.  The equivalent of confining the
# provider based on OS is instead done here.
#
# Copyright (c) 2012 Dominic Cleal
# Licensed under the Apache License, Version 2.0

require File.dirname(__FILE__) + '/../../../augeasproviders/provider'
require File.dirname(__FILE__) + '/../../../augeasproviders/mounttab/fstab'
require File.dirname(__FILE__) + '/../../../augeasproviders/mounttab/vfstab'

Puppet::Type.type(:mounttab).provide(:augeas) do
  desc "Uses Augeas API to update the /etc/(v)fstab file"

  def self.osimpl
    os = Facter.value(:osfamily) or Facter.value(:operatingsystem)
    case os
    when "Solaris"
      AugeasProviders::Mounttab::Vfstab
    else
      AugeasProviders::Mounttab::Fstab
    end
  end

  include AugeasProviders::Provider

  default_file do
    osimpl.default_file
  end

  lens do
    osimpl.lens
  end

  resource_path do |resource, path|
    "#{path}/*[file = '#{resource[:name]}']"
  end

  confine :feature => :augeas
  confine :exists => target
  defaultfor :feature => :augeas

  def self.instances
    augopen do |aug, path|
      resources = []
      aug.match("#{path}/*").each do |mpath|
        entry = osimpl.get_resource(aug, mpath, target)
        resources << new(entry) unless entry.nil?
      end
      resources
    end
  end

  def create 
    augopen! do |aug, path|
      self.class.osimpl.create(aug, path, resource)
    end
  end

  def device
    augopen do |aug, path|
      aug.get('$resource/spec')
    end
  end

  def device=(value)
    augopen! do |aug, path|
      aug.set('$resource/spec', value)
    end
  end

  def blockdevice
    augopen do |aug, path|
      aug.get('$resource/fsck') or "-"
    end
  end

  def blockdevice=(value)
    augopen! do |aug, path|
      if value == "-"
        aug.rm('$resource/fsck')
      else
        if aug.match('$resource/fsck').empty?
          aug.insert('$resource/spec', 'fsck', false)
        end
        aug.set('$resource/fsck', value.to_s)
      end
    end
  end

  def fstype
    augopen do |aug, path|
      aug.get('$resource/vfstype')
    end
  end

  def fstype=(value)
    augopen! do |aug, path|
      aug.set('$resource/vfstype', value)
    end
  end

  def options
    augopen do |aug, path|
      opts = []
      aug.match('$resource/opt').each do |opath|
        opt = aug.get(opath)
        optv = aug.get("#{opath}/value")
        opt = "#{opt}=#{optv}" if optv
        opts << opt
      end
      opts = opts.join(",")

      # [] and ["defaults"] are synonyms, so return what the user requested if
      # the current value is one of these to avoid changes
      empties = self.class.osimpl.empty_options
      if empties.include?(opts) and empties.include?(resource.should(:options))
        resource.should(:options)
      else
        opts
      end
    end
  end

  def insoptions(aug, entry, resource)
    self.class.osimpl.insoptions(aug, entry, resource)
  end

  def options=(values)
    augopen! do |aug, path|
      insoptions(aug, '$resource', resource)
    end
  end

  def dump
    augopen do |aug, path|
      self.class.osimpl.dump(aug, path, resource)
    end
  end

  def dump=(value)
    augopen! do |aug, path|
      self.class.osimpl.set_dump(aug, path, resource, value)
    end
  end

  def pass
    augopen do |aug, path|
      self.class.osimpl.pass(aug, path, resource)
    end
  end

  def pass=(value)
    augopen! do |aug, path|
      self.class.osimpl.set_pass(aug, path, resource, value)
    end
  end

  def atboot
    augopen do |aug, path|
      self.class.osimpl.atboot(aug, path, resource)
    end
  end

  def atboot=(value)
    augopen! do |aug, path|
      self.class.osimpl.set_atboot(aug, path, resource, value)
    end
  end
end
